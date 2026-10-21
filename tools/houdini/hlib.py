"""Shared helpers for the Houdini prop generators (run under hython).

Each generator builds a SOP network inside a subnet, turns the subnet into an
HDA in tools/houdini/otls/, then exports glTF through the glTF ROP with the
`path` primitive attribute as the mesh hierarchy. Units are metres, Y-up,
front facing -Z, origin at the ground centre.
"""
import os
import hou

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(TOOLS))
OTLS = os.path.join(TOOLS, "otls")
PREVIEWS = os.path.join(TOOLS, "previews")
PROPS = os.path.join(ROOT, "assets", "props", "houdini")

# Flat base colours; Godot applies its own toon shader.
MATERIALS = {
    "body": (0.85, 0.22, 0.16),
    "glass": (0.22, 0.33, 0.42),
    "tire": (0.08, 0.08, 0.09),
    "rim": (0.78, 0.78, 0.8),
    "trim": (0.14, 0.14, 0.16),
    "metal": (0.62, 0.64, 0.67),
    "light": (1.0, 0.95, 0.72),
    "taillight": (0.85, 0.08, 0.08),
    "plastic": (0.18, 0.45, 0.26),
    "paper": (0.93, 0.91, 0.84),
    "cardboard": (0.74, 0.56, 0.35),
    "can_red": (0.85, 0.12, 0.12),
    "can_blue": (0.15, 0.35, 0.85),
    "bag_yellow": (0.98, 0.78, 0.12),
    "bag_purple": (0.55, 0.25, 0.75),
    "concrete": (0.64, 0.62, 0.58),
    "plate": (0.95, 0.95, 0.9),
    "body2": (0.96, 0.95, 0.9),
    "surfboard": (0.98, 0.62, 0.18),
    "can": (1.0, 1.0, 1.0),
}


def hda_parms(seed=1, colour=None, size=1.0, extra=()):
    """Parameter templates every prop HDA exposes: seed, colour, size."""
    t = [
        hou.IntParmTemplate("seed", "Seed", 1, default_value=(seed,), min=0, max=100),
        hou.FloatParmTemplate("size", "Size", 1, default_value=(size,), min=0.1, max=3.0),
    ]
    if colour is not None:
        t.insert(1, hou.FloatParmTemplate("colour", "Colour", 3, default_value=colour,
            naming_scheme=hou.parmNamingScheme.RGBA, look=hou.parmLook.ColorSquare))
    return t + list(extra)


class Builder:
    """Adds tagged parts to a SOP subnet and merges them into one output."""

    def __init__(self, net):
        self.net = net
        self.parts = []

    def _n(self, kind, name):
        return self.net.createNode(kind, name)

    def tag(self, node, mat, path, keep=True):
        w = self._n("attribwrangle", node.name() + "_tag")
        w.setInput(0, node)
        w.parm("class").set("primitive")
        w.parm("snippet").set('s@shop_materialpath = "/mat/%s"; s@path = "%s";' % (mat, path))
        if keep:
            self.parts.append(w)
        return w

    def wrangle(self, node, snippet, cls="point", name=None):
        w = self._n("attribwrangle", name or node.name() + "_w")
        w.setInput(0, node)
        w.parm("class").set(cls)
        w.parm("snippet").set(snippet)
        return w

    def bevel(self, node, offset, divs):
        b = self._n("polybevel", node.name() + "_bev")
        b.setInput(0, node)
        b.parm("offset").set(offset)
        b.parm("divisions").set(divs)
        b.parm("filletshape").set("round")
        b.parm("ignoreflatedges").set(1)
        return b

    def box(self, name, size, center, mat, path, bevel=0.0, divs=2, taper=None, taper_below=False, divsxyz=None,
            rot=None, taper_from=None, tag=True):
        """Box, optionally rotated, tapered at the top (or bottom) and round-bevelled.

        taper = (scale x, scale z, shift z) applied to points above (or below) the centre; taper_from = (x, y, z)
        tapers about another box's centre instead, so pillars and trims follow a tapered cabin.
        tag=False returns the untagged node (for Booleans).
        """
        b = self._n("box", name)
        b.parm("type").set("polymesh")
        for a, v in zip("xyz", size):
            b.parm("size" + a).set(v)
        for a, v in zip("xyz", center):
            b.parm("t" + a).set(v)
        for i, v in enumerate(divsxyz or (1, 1, 1)):
            b.parm("divrate%d" % (i + 1)).set(v + 1)
        if rot:
            for a, v in zip("xyz", rot):
                b.parm("r" + a).set(v)
        n = b
        if taper:
            # Linear ramp over the tapered volume's height: unchanged at the bottom, full taper at the top
            # (reversed with taper_below). taper_from = (cx, y bottom, cz, y top) of the volume to follow.
            cx, y0, cz, y1 = taper_from or (center[0], center[1] - size[1] * 0.5, center[2], center[1] + size[1] * 0.5)
            k0, k1 = (1, 0) if taper_below else (0, 1)
            n = self.wrangle(n, (
                "float k = fit(@P.y, %f, %f, %d, %d);"
                " @P.x = %f + (@P.x - %f) * lerp(1, %f, k);"
                " @P.z = %f + (@P.z - %f) * lerp(1, %f, k) + %f * k;"
                % (y0, y1, k0, k1, cx, cx, taper[0], cz, cz, taper[1], taper[2])))
        if bevel > 0:
            n = self.bevel(n, bevel, divs)
        return self.tag(n, mat, path) if tag else n

    def cyl(self, name, rad, height, center, mat, path, orient="x", cols=16, rad2=None, bevel=0.0, divs=1, rows=2):
        t = self._n("tube", name)
        t.parm("type").set("poly")
        t.parm("orient").set(orient)
        t.parm("cap").set(1)
        t.parm("rad1").set(rad)
        t.parm("rad2").set(rad if rad2 is None else rad2)
        t.parm("height").set(height)
        t.parm("cols").set(cols)
        t.parm("rows").set(rows)
        for a, v in zip("xyz", center):
            t.parm("t" + a).set(v)
        n = t
        if bevel > 0:
            n = self.bevel(n, bevel, divs)
        return self.tag(n, mat, path)

    def merge(self, name="merge_parts"):
        m = self._n("merge", name)
        for i, p in enumerate(self.parts):
            m.setInput(i, p)
        self.parts = []
        return m

    def finish(self, src=None, cusp=35.0, size_expr='ch("../size")', normals=True):
        """Merge, split n-gons to quads/tris, cut normals at hard edges, scale, output."""
        m = src or self.merge()
        d = self._n("divide", "quads_only")
        d.setInput(0, m)
        d.parm("convex").set(1)
        d.parm("usemaxsides").set(1)
        d.parm("numsides").set(4)
        nrm = self._n("normal", "hard_edges")
        nrm.setInput(0, d)
        nrm.bypass(not normals)
        nrm.parm("type").set("typevertex")
        nrm.parm("cuspangle").set(cusp)
        x = self._n("xform", "size")
        x.setInput(0, nrm)
        x.parm("scale").setExpression(size_expr)
        x.parm("updatenmls").set(1)
        out = self._n("output", "OUT")
        out.setInput(0, x)
        self.net.layoutChildren()
        return out


def make_asset(geo_name, hda_name, label, parm_templates, build):
    """Create /obj/<geo>/<subnet>, add parms, build, save as an HDA. Returns the HDA node."""
    os.makedirs(OTLS, exist_ok=True)
    geo = hou.node("/obj").createNode("geo", geo_name)
    for c in geo.children():
        c.destroy()
    sub = geo.createNode("subnet", hda_name)
    ptg = sub.parmTemplateGroup()
    for t in parm_templates:
        ptg.append(t)
    sub.setParmTemplateGroup(ptg)
    build(Builder(sub))
    path = os.path.join(OTLS, "skatepark_%s.hda" % hda_name).replace("\\", "/")
    try:
        node = sub.createDigitalAsset(name="skatepark::" + hda_name, hda_file_name=path,
            description=label, min_num_inputs=0, max_num_inputs=0, ignore_external_references=True)
        node.type().definition().updateFromNode(node)
        node.matchCurrentDefinition()
    except hou.Error as e:
        print("HDA FAILED %s: %s" % (hda_name, e))
        node = sub
    node.setDisplayFlag(True)
    node.setRenderFlag(True)
    return node


def ensure_materials(overrides=None):
    mat = hou.node("/mat")
    for name, rgb in MATERIALS.items():
        if overrides and name in overrides:
            rgb = overrides[name]
        m = mat.node(name) or mat.createNode("principledshader::2.0", name)
        m.parmTuple("basecolor").set(rgb)
        m.parm("rough").set(0.65)
        m.parm("reflect").set(0.1)
        m.parm("metallic").set(0.0)


def tri_counts(node):
    """Triangles per path value and total, for the cooked SOP geometry."""
    geo = node.geometry()
    counts = {}
    for prim in geo.prims():
        key = prim.attribValue("path") if geo.findPrimAttrib("path") else "mesh"
        counts[key] = counts.get(key, 0) + max(prim.numVertices() - 2, 0)
    return counts


def export_glb(node, filename):
    os.makedirs(PROPS, exist_ok=True)
    return export_glb_to(node, os.path.join(PROPS, filename))


def export_glb_to(node, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    rop = hou.node("/out").createNode("gltf")
    rop.parm("usesoppath").set(1)
    rop.parm("soppath").set(node.path())
    rop.parm("buildfrompath").set(1)
    rop.parm("pathattrib").set("path")
    rop.parm("exportmaterials").set(1)
    rop.parm("exportcustomattributes").set(0)
    rop.parm("outputfile").set(out_path.replace("\\", "/"))
    rop.render()
    rop.destroy()
    return out_path


def report(name, node):
    c = tri_counts(node)
    total = sum(c.values())
    print("%-22s %6d tris  %s" % (name, total, ", ".join("%s=%d" % kv for kv in sorted(c.items()))))
    return total


def preview(node, png, overrides=None, res=(800, 500), azimuth=35.0, elevation=20.0, radius=None, center=None):
    """OpenGL ROP render of the node's geometry from a three-quarter front view."""
    import math
    os.makedirs(PREVIEWS, exist_ok=True)
    ensure_materials(overrides)
    bb = node.geometry().boundingBox()
    c = hou.Vector3(center) if center else bb.center()
    radius = radius or bb.sizevec().length() * 0.5
    fov = 2 * math.atan(math.tan(math.radians(22.5)) * min(1.0, res[1] / float(res[0])))  # narrow axis
    dist = radius / math.tan(fov * 0.5)
    az, el = math.radians(azimuth), math.radians(elevation)
    pos = hou.Vector3(c[0] - dist * math.cos(el) * math.sin(az), c[1] + dist * math.sin(el),
        c[2] - dist * math.cos(el) * math.cos(az))
    d = (c - pos).normalized()
    ground = hou.node("/obj").createNode("geo", "preview_ground")
    g = ground.createNode("grid")
    g.parm("sizex").set(radius * 8)
    g.parm("sizey").set(radius * 8)
    g.parmTuple("t").set((c[0], -0.002, c[2]))
    ground.parm("shop_materialpath").set("/mat/concrete")
    cam = hou.node("/obj").createNode("cam", "preview_cam")
    cam.parmTuple("t").set(tuple(pos))
    cam.parmTuple("r").set((math.degrees(math.asin(d[1])), math.degrees(math.atan2(-d[0], -d[2])), 0))
    cam.parm("resx").set(res[0])
    cam.parm("resy").set(res[1])
    rop = hou.node("/out").createNode("opengl", "preview_gl")
    rop.parm("camera").set(cam.path())
    rop.parm("picture").set(png.replace("\\", "/"))
    rop.parm("tres").set(1)
    rop.parm("res1").set(res[0])
    rop.parm("res2").set(res[1])
    rop.render()
    rop.destroy()
    cam.destroy()
    return png


def apply(node, parms):
    for k, v in parms.items():
        if isinstance(v, tuple):
            node.parmTuple(k).set(v)
        else:
            node.parm(k).set(v)


def run(make, variants):
    """Build the HDA, export every variant, print triangle counts. Returns {glb: tris}."""
    node = make()
    totals = {}
    for fname, parms, mats in variants:
        apply(node, parms)
        ensure_materials(mats)
        export_glb(node, fname)
        totals[fname] = report(fname, node)
    return totals


def set_pivot(glb_path, node_name, pivot):
    """Move a glb node's origin to `pivot` (body space): shift its mesh positions by -pivot and give the node the
    translation +pivot, so the part rotates about the pivot in the engine (the glTF ROP writes identity nodes)."""
    import json
    import struct
    data = bytearray(open(glb_path, "rb").read())
    jlen = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + jlen].decode("utf-8"))
    bin_start = 20 + jlen + 8
    node = next(n for n in doc["nodes"] if n.get("name") == node_name)
    mesh = doc["meshes"][node["mesh"]]
    for prim in mesh["primitives"]:
        acc = doc["accessors"][prim["attributes"]["POSITION"]]
        view = doc["bufferViews"][acc["bufferView"]]
        base = bin_start + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride") or 12
        for i in range(acc["count"]):
            o = base + i * stride
            x, y, z = struct.unpack_from("<3f", data, o)
            struct.pack_into("<3f", data, o, x - pivot[0], y - pivot[1], z - pivot[2])
        acc["min"] = [m - p for m, p in zip(acc["min"], pivot)]
        acc["max"] = [m - p for m, p in zip(acc["max"], pivot)]
    node["translation"] = list(pivot)
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = data[20 + jlen:]
    out = bytearray(data[:12]) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest
    struct.pack_into("<I", out, 8, len(out))
    open(glb_path, "wb").write(bytes(out))
