# JSON‑VIPB Action – Onboarding Guide

Welcome!  This document explains how to:

1.  Install / update the action (`v1.3.0`)
2.  Understand the three operating modes
3.  Set up common workflows (round‑trip, patch‑first, seed‑only)
4.  Run local tests with Pester / Docker

---

## 1. Install or upgrade

```bash
# root of your consumer repo
gh secret set GHCR_PAT <YOUR_GITHUB_TOKEN_WITH_write:packages>
# (Only needed if you host the image privately)

# reference in workflow
uses: svelderrainruiz/json-vipb@v1.3.0
The v1.3.0 Docker image is published at
> ghcr.io/svelderrainruiz/json-vipb:v1.3.0