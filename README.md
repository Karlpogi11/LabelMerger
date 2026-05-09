# LabelMerger

Merge a dropped label PDF with your overlay PDF on macOS.

## Download (easy)

1. Open Releases: https://github.com/Karlpogi11/LabelMerger/releases
2. Download `LabelMerger-macOS.zip`
3. Unzip and move `LabelMerger.app` to `~/Applications`

## Local install script

```bash
curl -fsSL https://raw.githubusercontent.com/Karlpogi11/LabelMerger/main/install.sh | bash
```

- Installs to `~/Applications/LabelMerger.app`
- Local only
- Falls back to local source build when no release asset exists yet

## Create a release

A GitHub Action is included:
- File: `.github/workflows/release.yml`
- Trigger: push tag starting with `v` (example: `v1.0.0`)

```bash
git tag v1.0.0
git push origin v1.0.0
```

After the workflow finishes, download `LabelMerger-macOS.zip` from the release page.
