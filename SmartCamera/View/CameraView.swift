//
//  CameraView.swift
//  SmartCamera
//
//  Created by Anton on 07.08.2021.
//

import SwiftUI

struct CameraView: View {
    
    @StateObject private var camera = CameraViewModel()
    @State private var torch: Bool = false
    
    private var torchIcon: String {
        return torch ? "bolt" : "bolt.slash"
    }
    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea(.all, edges: .all)
            
            VStack {
                Text(camera.result)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(#colorLiteral(red: 0.2784047723, green: 0.2784489095, blue: 0.2783908844, alpha: 1)))
                    .frame(width: 250, height: 20, alignment: .center)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color(#colorLiteral(red: 0.5001713037, green: 0.5103359818, blue: 0.5254879594, alpha: 1)), lineWidth: 1.5)
                    )
                HStack {
                    if !camera.isTaken {
                        VStack {
                            Button(action: {
                                torch.toggle()
                                camera.toggleTorch(on: torch)
                            }, label: {
                                Image(systemName: torchIcon)
                                    .foregroundColor(.black)
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(Circle())
                            })
                            Menu {
                                Button { camera.name = "MobileNet" } label: {
                                    Text("MobileNet")
                                }
                                
                                Button { camera.name = "Food" } label: {
                                    Text("Food")
                                }
                                Button { camera.name = "Flowers" } label: {
                                    Text("Flowers")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                    .frame(width: 15, height: 15)
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.leading, 10)
                    }
                    Spacer()
                    if camera.isTaken {
                        Button(action:
                                camera.retakePhoto
                               , label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .foregroundColor(.black)
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(Circle())
                               })
                            .padding(.trailing, 10)
                    }
                }
                
                Spacer()
                
                HStack {
                    if camera.isTaken {
                        Button(action: {
                            if !camera.isSaved{
                                camera.savePhoto()
                            }
                        }, label: {
                            Text(camera.isSaved ? "Saved" : "Save")
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color.white)
                                .clipShape(Capsule())
                        })
                        .padding(.leading)
                        Spacer()
                    } else {
                        Button(action: camera.capturePhoto, label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            }
                        })
                    }
                }
                .frame(height: 75)
            }
        }
        .onAppear {
            camera.checkAuthorization()
        }
        .alert(isPresented: $camera.alert) {
            Alert(title: Text("Please Enable Camera Access"))
        }
        
    }
}
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
