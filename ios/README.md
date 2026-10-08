# PlantGuard for iPhone

On-device apple leaf disease detection, orchard mapping and cross-season tracking, built on the
fine-tuned ResNet-50 from *Data-Driven Solutions in Agriculture: Machine Learning for Apple Disease
Classification* (Acharla & Kandasamy, IEEE SusTech). Everything — the model, the database, the
forecast — runs locally on the phone.

## Run it

Requirements: Xcode 27 (iOS 18+ simulator or device), [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd ios
xcodegen generate          # creates PlantGuard.xcodeproj from project.yml
open PlantGuard.xcodeproj
```

**Simulator:** pick any iPhone simulator and press Run. There's no camera in the Simulator — drag
leaf photos onto the Simulator window to add them to Photos, then scan from Photos. To "stand in"
the orchard, use *Features ▸ Location ▸ Custom Location* with the orchard coordinates shown in
Settings, then *Assign to a tree ▸ Use the tree I'm standing at*.

**iPhone (for the live camera):**
1. Plug the phone in and tap *Trust*. Turn on *Settings ▸ Privacy & Security ▸ Developer Mode*.
2. In Xcode: *Settings ▸ Accounts* → add your Apple ID (a free account works).
3. Select the PlantGuard target ▸ *Signing & Capabilities* ▸ choose your team. If the bundle ID is
   taken, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and regenerate.
4. Choose your iPhone as the run destination and press Run. The first time, approve the developer
   certificate on the phone under *Settings ▸ General ▸ VPN & Device Management*.

## What's inside

| Area | Where |
|---|---|
| Core ML model + inference, occlusion attention map | `PlantGuard/ML/` |
| Live camera with real-time classification | `PlantGuard/Features/Scan/LiveCamera.swift` |
| SwiftData schema (orchard, blocks, trees, scans, treatments, notes) | `PlantGuard/Models/Records.swift` |
| Disease library, season-aware care planner | `PlantGuard/Knowledge/DiseaseLibrary.swift` |
| Mills-table infection risk + offline weather simulator | `PlantGuard/Knowledge/Forecast.swift` |
| Demo orchard + nine-season epidemic simulation | `PlantGuard/Data/DemoSeeder.swift` |
| Cross-season analytics | `PlantGuard/Data/OrchardAnalytics.swift` |
| Screens | `PlantGuard/Features/` |

### Demo data

Onboarding offers a demo orchard: 254 trees in four blocks, with nine seasons of simulated field
surveys. The history comes from a simple spatial epidemic model (infections spread to neighbours,
scab and mildew overwinter, rust clusters near a cedar windbreak, 2025 is a wet outbreak year, and
2026's spray programs reduce disease). Forecast weather is generated from regional climate normals
and the community feed is sample content — both are labelled as such in the app.

### Re-converting the model

```bash
python ios/scripts/convert_coreml.py "ResNet_50_Best_Model (1).h5" ios/PlantGuard/ML/PlantGuardClassifier.mlpackage
python ios/scripts/verify_coreml.py  "ResNet_50_Best_Model (1).h5" ios/PlantGuard/ML/PlantGuardClassifier.mlpackage
```

Needs `tensorflow` (2.16+, for the Keras 3 `.h5`) and `coremltools`. The ResNet "caffe"
preprocessing (RGB→BGR, ImageNet mean subtraction) is built into the Core ML image input; the
verification script compares Core ML and Keras outputs on synthetic images (max difference 0.002 at
conversion time).
