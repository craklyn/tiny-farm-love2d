---
name: vision-ux-critique
description: A workflow for capturing local graphical output (via screenshots or virtual framebuffers) and orchestrating a Gemini Vision model to act as an L6 Sr UX Designer to critique and validate UI/UX implementations. Use this skill when you need to ensure pixel-perfect rendering, layout cohesion, and high accessibility standards without relying on blind guessing.
---

# Vision-Driven UX Critique Pipeline

This skill defines the meta-process for using AI vision models to iteratively evaluate and improve local UI/UX rendering.

## 1. Perception (Visual Capture)
You cannot fix what you cannot see. 
- Implement a deterministic screenshot mechanism in the target application (e.g., `love.graphics.captureScreenshot()` in LÖVE, or similar viewport captures in Godot).
- Use `xvfb-run` if running in a headless Linux environment to capture OpenGL/graphical frames.
- Ensure the capture covers stress-test scenarios (empty states, max text length, edge cases).

## 2. Critique (Vision Agent)
Do not guess what looks good.
- Create a Python script utilizing the `google-genai` SDK to upload the captured screenshots to a Gemini model (e.g., `gemini-3.6-flash`).
- Prompt the model to act as an **L6 Sr UX Designer**. 
- Instruct the model to strictly evaluate:
  - 9-slice rendering artifacts (stretching, scaling issues).
  - Data display hierarchy and alignment.
  - Typography legibility and contrast ratios.
  - Overall aesthetic cohesion.
- Output the critique to a structured markdown file (e.g., `ux_critique.md`).

## 3. First-Principles Redesign
- Do not immediately start hacking code.
- Read the critique and define a strict set of design tokens: exact padding values, safe-zones, font sizes, and hex color palettes.
- Only once the mathematical spec is defined should you procure/generate assets that match it.

## 4. Execution & Validation
- Refactor the UI code to adhere strictly to the new design spec.
- Re-capture the visuals using the method from Step 1.
- Pass the new visuals back through the Vision Agent in Step 2 to validate that all L6 criteria are met. Iterate if necessary.
