import AppKit
import SwiftUI
struct Demo: View {
 let values = [0.46, 0.61, 0.99, 1.0]
 func gauge(_ value: Double) -> some View {
   Gauge(value: value) { EmptyView() }.gaugeStyle(.accessoryCircularCapacity).tint(.green)
 }
 func scaled(_ value: Double) -> some View {
   gauge(value).fixedSize().visualEffect { c,g in c.scaleEffect(112/max(g.size.width,g.size.height)) }.frame(width:112,height:112)
 }
 var body: some View {
 VStack(spacing:16) {
  HStack { Text("Gauge render comparison"); Spacer() }
  HStack { Text("value").frame(width:130); ForEach(values,id:\.self) {v in Text("\(Int(v*100))%").frame(width:120) } }
  HStack { Text("Native / no scaling").frame(width:130); ForEach(values,id:\.self) {v in gauge(v).frame(width:120,height:112) } }
  HStack { Text("Current visualEffect").frame(width:130); ForEach(values,id:\.self) {v in scaled(v).frame(width:120,height:112) } }
  HStack { Text("Uniform gradient").frame(width:130); ForEach(values,id:\.self) {v in gauge(v).tint(LinearGradient(colors: [.green, .green], startPoint: .leading, endPoint: .trailing)).scaleEffect(2).frame(width:112,height:112).frame(width:120,height:112) } }
  HStack { Text("drawingGroup linear").frame(width:130); ForEach(values,id:\.self) {v in scaled(v).drawingGroup(colorMode:.linear).frame(width:120,height:112) } }
  HStack { Text("drawingGroup default").frame(width:130); ForEach(values,id:\.self) {v in scaled(v).drawingGroup().frame(width:120,height:112) } }
 }.padding(24).background(.white)
 }
}
let app=NSApplication.shared
app.setActivationPolicy(.regular)
let host=NSHostingView(rootView:Demo())
let win=NSWindow(contentRect:NSRect(x:200,y:200,width:720,height:820),styleMask:[.titled,.closable],backing:.buffered,defer:false)
win.title="Gauge rendering diagnostics — window shadow OFF"
win.hasShadow = false
win.contentView=host
win.center()
win.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps:true)
app.run()
