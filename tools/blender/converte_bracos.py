"""FPS ARMS RIG 1 (braços em primeira pessoa, rig com 50 ossos, dedos incluídos) -> GLB para o jogo.
O modelo original está em unidades de ~1 cm (braço de ~58 unidades): escala 0,1 -> 0,58 m. Mantém a ação de teste como "teste".
Uso: python tools/blender/converte_bracos.py "FPS ARMS RIG 1 test anim.blend" saida.glb"""
import bpy, sys, os

src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=src)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
for o in list(bpy.data.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
arm.scale = (0.1, 0.1, 0.1)
act = bpy.data.actions.get("caucasian_male_1Action")
if act:
    act.name = "teste"
    arm.animation_data.action = act
for a in bpy.data.actions:
    a.use_fake_user = True
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True, export_image_format="JPEG", export_jpeg_quality=90,
                          export_materials="EXPORT", export_cameras=False, export_lights=False, export_animations=True,
                          export_animation_mode="ACTIONS")
print("[bracos] exportado %s (%d KB); ossos=%d" % (dst, os.path.getsize(dst) // 1024, len(arm.data.bones)))
