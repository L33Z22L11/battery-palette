import Foundation

@main struct WidgetRegistrationTests {
    static func main() {
        let app = URL(fileURLWithPath: "/Applications/Test.app")
        let ext = app.appendingPathComponent("Contents/PlugIns/BatteryPaletteWidget.appex")
        let present = "     local.test(1.2)\tuuid\tdate\t" + ext.path + "\n (1 plug-in)"
        func check(_ outputs: [RegistrationCommandResult], _ expected: WidgetRegistrationRepair.Outcome, _ expectedCommands: [String]) {
            var index = 0
            var commands: [String] = []
            let result = WidgetRegistrationRepair.repair(appURL: app, identifier: "local.test") { executable, args in
                commands.append(URL(fileURLWithPath: executable).lastPathComponent + " " + args[0])
                precondition(index < outputs.count)
                defer { index += 1 }
                return outputs[index]
            }
            precondition(result == expected && commands == expectedCommands && index == outputs.count)
        }
        func ok(_ output: String = "") -> RegistrationCommandResult { .init(status: 0, output: output) }
        let fail = RegistrationCommandResult(status: 1, output: "")
        check([ok(present)], .registered, ["pluginkit -m"])
        check([ok("-" + present)], .disabled, ["pluginkit -m"])
        check([fail], .failed, ["pluginkit -m"])
        check([ok(), ok(), ok(), ok(present)], .repaired, ["pluginkit -m", "lsregister -f", "pluginkit -a", "pluginkit -m"])
        check([ok(present.replacingOccurrences(of: "/Applications/Test.app", with: "/tmp/Other.app")), ok(), ok(), ok(present)], .repaired, ["pluginkit -m", "lsregister -f", "pluginkit -a", "pluginkit -m"])
        check([ok(), fail], .failed, ["pluginkit -m", "lsregister -f"])
        check([ok(), ok(), fail], .failed, ["pluginkit -m", "lsregister -f", "pluginkit -a"])
        check([ok(), ok(), ok(), ok()], .failed, ["pluginkit -m", "lsregister -f", "pluginkit -a", "pluginkit -m"])
        print("8 widget registration recovery checks passed")
    }
}
