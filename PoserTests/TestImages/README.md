# Test Images

Drop reference photos here to enable real-photo (Vision-pipeline) tests.

## Add exactly these 3 files (JPEG or PNG)

| Filename        | Suggested pose                                  |
|-----------------|-------------------------------------------------|
| `pose1.jpg`     | Front-facing, full-body standing                |
| `pose2.jpg`     | Dynamic / action pose (running, reaching, etc.) |
| `pose3.jpg`     | Hands-on-hips or seated (occlusion stress test) |

(If you use `.png`, keep the same base names: `pose1.png`, etc.)

## Guidelines for good fixtures
- **Single person**, full body in frame, unobstructed.
- **Plain / uncluttered background** → cleaner segmentation mask.
- Decent **resolution and lighting**.
- **You must own the rights** — these get committed to the repo.

## What happens after you add them
Anything in `PoserTests/` is bundled into the test target, so the images are
loadable at test time via `Bundle(for:).url(forResource:withExtension:)`.

Tell me once they're in and I'll wire up either:
- **Baked fixtures** — capture each photo's detected pose once (on device) and
  hardcode it, so snapshot tests stay Simulator/CI-friendly; or
- **Live integration tests** — run the real `PoseDetector` on these images
  (device-only, since Vision body-pose doesn't run on the Simulator).
