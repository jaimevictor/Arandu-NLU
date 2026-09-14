# Arandu NLU - GitHub Push Instructions

## Repository Setup

**Repository name:** `arandu-nlu`  
**Description:** Brazilian Portuguese local NLU for Home Assistant  
**Tagline:** Sua língua. Sua casa. Seu controle.

## Current Status

✅ Git repository initialized  
✅ Initial commit created (96c2546)  
✅ 4,136 files committed  
✅ README updated with Arandu branding  

## To Push to GitHub

### 1. Create Repository on GitHub

Go to: https://github.com/new

- **Repository name:** `arandu-nlu`
- **Description:** `Brazilian Portuguese local NLU for Home Assistant`
- **Visibility:** Public (recommended - Apache-2.0 licensed)
- **DO NOT** initialize with README, .gitignore, or license (already present)

### 2. Add Remote and Push

```bash
cd "E:\Pycharm Projects\Sophia NLU"
git remote add origin https://github.com/YOUR-USERNAME/arandu-nlu.git
git branch -M main
git push -u origin main
```

Replace `YOUR-USERNAME` with your GitHub username.

### 3. Set Repository Details

After pushing, configure on GitHub:

**Topics (suggested):**
- `home-assistant`
- `nlu`
- `portuguese`
- `smart-home`
- `rust`
- `python`
- `voice-assistant`
- `local-first`
- `privacy`

**Website:** (optional) Link to Home Assistant docs or project page

**About:** Sua língua. Sua casa. Seu controle. - Local Brazilian Portuguese NLU for Home Assistant

## Known Issues

⚠️ **Duplicate "Complete MLP" folder committed** - The repository contains both:
- Production code at root (correct)
- Duplicate in `Complete MLP/` folder (extraction artifact)

**To clean up after first push:**

```bash
git rm -r "Complete MLP"
git rm -r implementation-clean-room
git rm -r archive
git commit -m "chore: remove duplicate and legacy folders"
git push
```

## Repository Structure

```
arandu-nlu/
├── addon/              # Rust NLU engine (Home Assistant add-on)
├── custom_components/  # Python HA integration
├── crates/             # Rust workspace crates
├── data/mlp/          # Synthetic corpus (Apache-2.0)
├── docs/              # Documentation and ADRs
├── schemas/           # JSON schemas
├── tests/             # Python integration tests
├── tools/             # Build and validation scripts
├── vendor/            # Vendored Rust dependencies
├── AGENTS.md          # Repository operating contract
├── LICENSE            # Apache-2.0
└── README.md          # Arandu project overview
```

## Next Steps

1. Create GitHub repo
2. Push code
3. Clean up duplicate folders
4. Set up CI/CD (optional)
5. Add repository topics
6. Create first release after full validation passes
