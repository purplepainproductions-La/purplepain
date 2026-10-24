# Free 3D Modeling Pipeline for Unreal Engine Using Google AI Studio

This pipeline lets you bypass expensive 3D generation tools by combining **Google AI Studio** with completely **free web-based 3D AI tools and open-source software (Blender)** to build engine-ready assets.

---

## 🛠️ The Ultimate Free Toolkit

| Stage | Free Tool | Primary Purpose |
| :--- | :--- | :--- |
| **1. Ideation & Concept** | [Google AI Studio](https://aistudio.google.com/) | Generates precise, orthogonal reference views and textures. |
| **2. Image-to-3D Generation** | [Tripo3D (Free Tier)](https://www.tripo3d.ai/) or [Rodin (Free Credits)](https://www.deemos.com/) | Conversions of 2D concept images into fully structured 3D `.obj` or `.fbx` meshes. |
| **3. Material Enhancement** | [Polycam Texture AI](https://poly.cam/tools/ai-texture-generator) or [Materialize (Open Source)](https://www.boundingboxsoftware.com/materialize/) | Extracts Normal, Roughness, and Metallic maps for PBR engine compatibility. |
| **4. Cleanup & Optimization** | [Blender](https://www.blender.org/) | Adjusts UV mapping, fixes topology scales, and clears non-standard roots. |
| **5. Runtime Sandbox** | [Unreal Engine 5](https://www.unrealengine.com/) | Real-time compilation, lighting adjustments, and collision baking. |

---

## 📋 Step-by-Step Blueprint

### Phase 1: Engine-Ready Reference Generation (Google AI Studio)
To prevent the 3D modeler from warping your shape, your reference image must have flat lighting and strict structural orientation.

1. Navigate to [Google AI Studio](https://aistudio.google.com/).
2. Select the **Gemini 1.5 Pro** or **Gemini 1.5 Flash** model.
3. Paste the following system setup to prompt an associated text-to-image generator, or use it to define structural constraints for concept creation:

> **Reference Constraint Prompt Matrix:**
> *"Generate a concept sheet for a [INSERT YOUR OBJECT HERE, e.g., Medieval Iron Broadsword]. The image must display a strict orthographic side view and front view on a solid, neutral gray background. Use completely flat, ambient studio lighting with zero cast shadows, zero directional light sources, and no environment background. The object must be isolated and fully visible within the borders."*

4. Run the query and **Download** the resulting high-resolution asset concept.

### Phase 2: Free 2D-to-3D Mesh Extraction
1. Open a free-tier account on [Tripo3D](https://www.tripo3d.ai/) or utilize [Rodin 3D](https://www.deemos.com/).
2. Upload your flat-lit reference image from Phase 1.
3. Select **Draft Quality** or **Standard Generation** (Free tiers typically grant multiple standard creations daily).
4. Export the resulting 3D geometry as an **OBJ** or **GLB** file.

### Phase 3: PBR Map Extraction (Free Web tools)
AI 3D models usually download with just a flat base-color image (Albedo). Unreal Engine needs specialized surface texture maps to reflect light properly.

1. Drop your isolated base texture image into a free utility like **Materialize** (Desktop Open Source) or use [Polycam's Free AI Texture Tool](https://poly.cam/tools/ai-texture-generator).
2. Generate a **Normal Map** (to simulate high-fidelity structural surface depth).
3. Generate a **Roughness Map** (specifying dry vs shiny patches).
4. Export these as individual `.png` or `.tga` files.

### Phase 4: Scaling & Pivot Correction (Blender)
Before dropping the model into a game engine, you must align its coordinate system so it spins and snaps properly.

1. Launch **Blender** and delete the default cube.
2. Select **File > Import** and load your `.obj` or `.glb` mesh file.
3. Tap `Tab` to enter **Edit Mode**, select the absolute bottom edge/vertices of your model, and press `Shift + S` -> **Cursor to Selected**.
4. Switch back to **Object Mode**, right-click the model, and select **Set Origin -> To 3D Cursor**. This locks your anchor point to the bottom center of the item.
5. Hit `N` to show the transform tab and ensure the dimensions match accurate real-world gaming metrics (e.g., a sword should be roughly 1 meter tall, not 40 meters).
6. Select **File > Export > FBX** (Check **Selected Objects Only** in the export parameters).

### Phase 5: Importing and Shading in Unreal Engine 5
1. Open Unreal Engine 5 and drag your cleaned-up `.fbx` mesh and your generated texture maps into the **Content Browser**.
2. **Double-click** your newly generated Material node to enter the node-graph editor.
3. Wire the maps into the Material Attributes:
   * **Base Color / Albedo Map** ➔ **Base Color**
   * **Normal Map** ➔ **Normal**
   * **Roughness Map** ➔ **Roughness** *(Double-click the Roughness Texture asset inside your directory and make sure "SRGB" checkbox is **Unchecked** for linear gray channels)*
4. Close the material editor, click **Apply**, and save changes.
5. Open the static mesh profile, navigate to the details panel, search for **Collision Complexity**, and shift the property setting to **Use Complex Collision as Simple**.

---

## 🎯 Pro-Tips for Maximizing AI-to-Unreal Workflows
* **Beware Base Lighting:** If your AI image has strong shadows, your Unreal model will appear permanently dark on one side, regardless of where game torches or sunlight are placed.
* **Keep Topology Low:** Free AI generators often create messy, hyper-dense triangle grids. Use Blender's **Decimate Modifier** set between `0.2 - 0.5` to aggressively slash polygon counts without losing visual sharpness.