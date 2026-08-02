# Model Asset Pack

TOKEN: YOUR_HF_TOKEN_HERE

Place `gemma3-1b-it-int4.task` here before building a release bundle.

## How to obtain the model

1. Accept the Gemma license at https://huggingface.co/litert-community/Gemma3-1B-IT
2. Download `gemma3-1b-it-int4.task` (~555 MB) using your HF access token:

```bash
huggingface-cli download litert-community/Gemma3-1B-IT gemma3-1b-it-int4.task \
    --local-dir android/model_delivery/src/main/assets/model/
```

Or with curl:
```bash
curl -L -H "Authorization: Bearer YOUR_HF_TOKEN" \
  "https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task" \
  -o android/model_delivery/src/main/assets/model/gemma3-1b-it-int4.task
```

## Notes

- This file is excluded from git (see root `.gitignore`).
- At build time, the Flutter/Gradle build will pick it up automatically.
- The app reads the model directly from the asset pack location via
  `AssetPackManager.getPackLocation()` — no extraction to app storage needed.
