import SwiftUI
import SceneKit

// MARK: - VoxelTreeView
struct VoxelTreeView: UIViewRepresentable {
    let healthPercentage: CGFloat

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.animateToHealth(healthPercentage)
    }

    func makeCoordinator() -> VoxelTreeCoordinator {
        VoxelTreeCoordinator(initialHealth: healthPercentage)
    }
}

// MARK: - VoxelTreeCoordinator
class VoxelTreeCoordinator: NSObject {
    let scene = SCNScene()
    private let treeRoot = SCNNode()
    private let cameraPivot = SCNNode()
    private var leafNodes: [SCNNode] = []
    private var branchNodes: [SCNNode] = []
    private var groundMoneyNodes: [SCNNode] = [] // Liste til at styre pengene på jorden
    
    private let fGreenDark   = UIColor(red: 0.18, green: 0.40, blue: 0.22, alpha: 1.0)
    private let fGreenMid    = UIColor(red: 0.28, green: 0.58, blue: 0.32, alpha: 1.0)
    private let fGreenLight  = UIColor(red: 0.42, green: 0.72, blue: 0.45, alpha: 1.0)
    private let fTrunk = UIColor(red: 159/255, green: 105/255, blue: 0/255, alpha: 1.0)

    init(initialHealth: CGFloat) {
        super.init()
        setupScene()
        buildTrunk()
        buildDeadBranches()
        buildCanopy()
        buildGroundMoney() // Nu integreret med health-logik
        applyHealth(initialHealth, animated: false)
    }

    private func setupScene() {
        scene.rootNode.addChildNode(treeRoot)
        cameraPivot.position = SCNVector3(0, 1.2, 0)
        scene.rootNode.addChildNode(cameraPivot)
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(0, 0, 8)
        cameraPivot.addChildNode(cameraNode)
        
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .directional
        light.light?.intensity = 1000
        light.position = SCNVector3(5, 10, 5)
        scene.rootNode.addChildNode(light)
        
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 600
        scene.rootNode.addChildNode(amb)
    }

    private func buildTrunk() {
        let geo = SCNBox(width: 0.35, height: 1.2, length: 0.35, chamferRadius: 0)
        geo.firstMaterial?.diffuse.contents = fTrunk
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(0, 0.6, 0)
        treeRoot.addChildNode(node)
        addBaseShadow()
    }

    // MARK: - Dynamiske penge på jorden
    private func buildGroundMoney() {
        let leafColors = [fGreenDark, fGreenMid, fGreenLight]
        let moneyCount = 25
        
        for i in 0..<moneyCount {
            let angle = Float.random(in: 0...(2 * .pi))
            let radius = Float.random(in: 0.4...1.4)
            let x = cos(angle) * radius
            let z = sin(angle) * radius
            
            let randomHeight = CGFloat.random(in: 0.08...0.25)
            let voxelSize: CGFloat = 0.12
            
            let geo = SCNBox(width: voxelSize, height: randomHeight, length: voxelSize, chamferRadius: 0)
            
            // --- BASE SHADOW LOGIK ---
            let baseColor = leafColors.randomElement() ?? fGreenMid
            
            // Vi laver 6 materialer (ét for hver side af boksen)
            // så vi kan styre skyggen på siderne
            let sideMat = SCNMaterial()
            sideMat.diffuse.contents = baseColor
            sideMat.lightingModel = .lambert
            
            // Vi tilføjer en lille "ambient occlusion" effekt i bunden via en mørk Multiply
            // Dette simulerer at bunden er mørkere end toppen
            let topMat = SCNMaterial()
            topMat.diffuse.contents = baseColor
            
            // Sæt materialerne på (rækkefølgen i SCNBox er: R, L, T, B, F, Back)
            geo.materials = [sideMat, sideMat, topMat, sideMat, sideMat, sideMat]
            
            // For at lave den faktiske "Base Shadow" på jorden under hver boks,
            // bruger vi en lille sort cirkel-node helt nede ved y = 0
            let shadowGeo = SCNPlane(width: voxelSize * 1.5, height: voxelSize * 1)
            let shadowMat = SCNMaterial()
            shadowMat.diffuse.contents = UIImage(systemName: "circle.fill")?.withTintColor(.black)
            shadowMat.transparency = 0.2 // Meget svag skygge
            shadowMat.lightingModel = .constant
            shadowGeo.materials = [shadowMat]
            
            let moneyNode = SCNNode(geometry: geo)
            moneyNode.position = SCNVector3(x, Float(randomHeight) / 2, z)
            
            let shadowNode = SCNNode(geometry: shadowGeo)
            shadowNode.eulerAngles.x = -.pi / 2 // Læg den fladt ned
            shadowNode.position = SCNVector3(0, -Float(randomHeight)/2 + 0.001, 0) // Lige under boksen
            
            // Saml dem i en container så de animerer sammen
            let containerNode = SCNNode()
            containerNode.addChildNode(moneyNode)
            containerNode.addChildNode(shadowNode)
            containerNode.position = SCNVector3(x, Float(randomHeight) / 2, z)
            moneyNode.position = SCNVector3(0, 0, 0) // Reset relativ til container
            
            let steps: [Float] = [0, .pi/2, .pi, 1.5 * .pi]
            containerNode.eulerAngles.y = steps.randomElement() ?? 0
            
            containerNode.opacity = 0
            containerNode.scale = SCNVector3(0.001, 0.001, 0.001)
            
            let threshold = CGFloat(i) / CGFloat(moneyCount)
            containerNode.setValue(threshold, forKey: "threshold")
            
            treeRoot.addChildNode(containerNode)
            groundMoneyNodes.append(containerNode)
        }
    }

    private func buildDeadBranches() {
        let branchConfigs: [(SCNVector3, SCNVector3, SCNVector3)] = [
            (SCNVector3(0.25, 1.0, 0), SCNVector3(0.6, 0.12, 0.12), SCNVector3(0, 0, 0.5)),
            (SCNVector3(-0.25, 0.9, 0), SCNVector3(0.5, 0.12, 0.12), SCNVector3(0, 0, -0.5)),
            (SCNVector3(0.1, 1.2, 0), SCNVector3(0.3, 0.1, 0.1), SCNVector3(0, 0, 0.8))
        ]

        for config in branchConfigs {
            let geo = SCNBox(width: CGFloat(config.1.x), height: CGFloat(config.1.y), length: CGFloat(config.1.z), chamferRadius: 0)
            geo.firstMaterial?.diffuse.contents = fTrunk
            let node = SCNNode(geometry: geo)
            node.position = config.0
            node.eulerAngles = config.2
            node.opacity = 0
            treeRoot.addChildNode(node)
            branchNodes.append(node)
        }
    }

    private func buildCanopy() {
        let yB: Float = 1.1
        let configs: [(Float, Float, Float, CGFloat, UIColor, CGFloat)] = [
            (0.0,   yB + 0.35,  0.0,  1.2, fGreenMid,   0.1),
            (-0.55, yB + 0.25, -0.2,  1.1, fGreenDark,  0.2),
            (0.5,   yB + 0.3,   0.2,  1.0, fGreenDark,  0.3),
            (-0.4,  yB + 1.0,   0.1,  0.9, fGreenLight, 0.4),
            (0.3,   yB + 0.75,  0.4,  0.8, fGreenLight, 0.5),
            (0.1,   yB + 0.6,  -0.5,  0.9, fGreenDark,  0.6),
            (-0.05, yB + 1.35,  0.0,  0.8, fGreenMid,   0.7),
            (0.45,  yB + 1.0,  -0.3,  0.7, fGreenLight, 0.8),
            (-0.35, yB + 0.85, -0.4,  0.7, fGreenDark,  0.9),
            (0.15,  yB + 1.6,   0.1,  0.6, fGreenMid,   1.0)
        ]
        
        for v in configs {
            let geo = SCNBox(width: v.3, height: v.3, length: v.3, chamferRadius: 0.01)
            geo.firstMaterial?.diffuse.contents = v.4
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(v.0, v.1, v.2)
            node.opacity = 0
            node.scale = SCNVector3(0.001, 0.001, 0.001)
            node.setValue(v.5, forKey: "threshold")
            treeRoot.addChildNode(node)
            leafNodes.append(node)
        }
    }

    func animateToHealth(_ health: CGFloat) {
        applyHealth(health, animated: true)
    }

    private func applyHealth(_ health: CGFloat, animated: Bool) {
        let isDead = health < 0.1
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.4 : 0
        
        // Blade på træet (forsvinder når health falder)
        for node in leafNodes {
            let t = node.value(forKey: "threshold") as? CGFloat ?? 0
            let isVisible = health >= t
            node.opacity = isVisible ? 1.0 : 0.0
            let s = Float(isVisible ? 1.0 : 0.001)
            node.scale = SCNVector3(s, s, s)
        }

        // Penge på jorden (dukker op når health falder)
        for node in groundMoneyNodes {
            let t = node.value(forKey: "threshold") as? CGFloat ?? 0
            // Hvis health er LAVERE end tærsklen, ligger bladet på jorden
            let isOnGround = health < t
            node.opacity = isOnGround ? 1.0 : 0.0
            let s = Float(isOnGround ? 1.0 : 0.001)
            node.scale = SCNVector3(s, s, s)
        }

        for branch in branchNodes {
            branch.opacity = isDead ? 1.0 : 0.0
        }
        
        SCNTransaction.commit()
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let xRotation = Float(translation.x) * (Float.pi / 180) * 0.4
        if gesture.state == .changed {
            cameraPivot.eulerAngles.y = -xRotation
        } else if gesture.state == .ended || gesture.state == .cancelled {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            cameraPivot.eulerAngles.y = 0
            SCNTransaction.commit()
        }
    }

    private func addBaseShadow() {
        let shadowGeo = SCNBox(width: 0.35, height: 1.2, length: 0.35, chamferRadius: 0)
        let mat = SCNMaterial()
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        gradient.colors = [UIColor.black.withAlphaComponent(0.15).cgColor, UIColor.black.withAlphaComponent(0.0).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        UIGraphicsBeginImageContext(gradient.bounds.size)
        gradient.render(in: UIGraphicsGetCurrentContext()!)
        mat.diffuse.contents = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        mat.lightingModel = .constant
        shadowGeo.materials = [mat]
        let shadowNode = SCNNode(geometry: shadowGeo)
        shadowNode.position = SCNVector3(0, -0.60, 0)
        treeRoot.addChildNode(shadowNode)
    }
}

// MARK: - Interactive Preview
struct InteractiveVoxelTest: View {
    @State private var health: CGFloat = 1.0
    var body: some View {
        VStack {
            VoxelTreeView(healthPercentage: health)
                .frame(height: 400)
            Slider(value: $health, in: 0...1).padding()
            Text("Health: \(Int(health * 100))%")
        }
    }
}

#Preview {
    InteractiveVoxelTest()
        .background(Color.gray.opacity(0.1))
}
