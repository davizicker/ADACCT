"""Importa captura de movimento (BVH, p.ex. banco gratuito da CMU) e adapta ao esqueleto criado por animar.py.
Usado por animar.py (--mocap tools/ia3d/mocap/clips.json). Não depende do importador de BVH do Blender: lê o arquivo
por conta própria e faz a cinemática direta (só rotações).

Método (retargeting por "delta em coordenadas do mundo"):
  1. lê o BVH; o quadro 0 dos arquivos da CMU é uma pose T, que serve de referência de repouso;
  2. para cada osso do alvo ligado a uma junta da fonte: delta(t) = G_fonte(t) · G_fonte(0)⁻¹ (rotação global relativa ao repouso);
  3. o delta é levado para os eixos do alvo (M · delta · M⁻¹; M alinha cima, frente e esquerda dos dois personagens);
  4. rotação desejada do osso = delta · rotação de repouso do osso alvo; vira a rotação local de pose descontando o pai;
  5. o movimento do quadril é escalado pela altura do alvo (e pode ser "no lugar", para animações em laço).
"""
import math, os
import bpy
from mathutils import Matrix, Vector, Quaternion

# osso do alvo (sem o sufixo de lado) -> junta do BVH da CMU ({L}/{R} viram Left/Right)
MAPA_HUMANOIDE = {
    "quadril": "Hips", "coluna": "Spine", "peito": "Spine1", "pescoco": "Neck", "cabeca": "Head",
    "braco": "{S}Arm", "antebraco": "{S}ForeArm", "mao": "{S}Hand",
    "coxa": "{S}UpLeg", "canela": "{S}Leg", "pe": "{S}Foot",
}


def ler_bvh(caminho):
    toks = open(caminho, encoding="utf-8", errors="ignore").read().split()
    i = 0
    juntas = []
    pilha = []

    def prox():
        nonlocal i
        t = toks[i]
        i += 1
        return t

    while i < len(toks):
        t = prox()
        if t in ("ROOT", "JOINT"):
            nome = prox()
            juntas.append({"nome": nome, "pai": pilha[-1] if pilha else -1, "canais": [], "offset": (0, 0, 0)})
            pilha.append(len(juntas) - 1)
        elif t == "End":
            prox()
            pilha.append(-2)       # End Site: marcador, sem junta
        elif t == "OFFSET":
            o = (float(prox()), float(prox()), float(prox()))
            if pilha and pilha[-1] >= 0:
                juntas[pilha[-1]]["offset"] = o
        elif t == "CHANNELS":
            n = int(prox())
            juntas[pilha[-1]]["canais"] = [prox() for _ in range(n)]
        elif t == "}":
            pilha.pop()
        elif t == "MOTION":
            break
    assert toks[i] == "Frames:"
    nf = int(toks[i + 1])
    assert toks[i + 2] == "Frame" and toks[i + 3] == "Time:"
    dt = float(toks[i + 4])
    i += 5
    nc = sum(len(j["canais"]) for j in juntas)
    dados = []
    for _ in range(nf):
        dados.append([float(x) for x in toks[i:i + nc]])
        i += nc
    return {"juntas": juntas, "frames": dados, "dt": dt}


def _rot_eixo(c, ang):
    return {"X": Matrix.Rotation(ang, 3, "X"), "Y": Matrix.Rotation(ang, 3, "Y"), "Z": Matrix.Rotation(ang, 3, "Z")}[c]


def cinematica(bvh):
    """Devolve, por quadro, ({nome: rotação global 3x3}, posição da raiz)."""
    juntas = bvh["juntas"]
    saida = []
    for fr in bvh["frames"]:
        k = 0
        glob = []
        raiz = Vector((0, 0, 0))
        for j in juntas:
            R = Matrix.Identity(3)
            pos = [0.0, 0.0, 0.0]
            for ch in j["canais"]:
                v = fr[k]
                k += 1
                eixo = ch[0]
                if ch.endswith("position"):
                    pos["XYZ".index(eixo)] = v
                else:
                    R = R @ _rot_eixo(eixo, math.radians(v))
            g = (glob[j["pai"]] @ R) if j["pai"] >= 0 else R
            glob.append(g)
            if j["pai"] < 0:
                raiz = Vector(pos)
        saida.append(({j["nome"]: glob[n] for n, j in enumerate(juntas)}, raiz))
    return saida


def _dist_rot(A, B):
    d = A.transposed() @ B
    c = max(-1.0, min(1.0, (d[0][0] + d[1][1] + d[2][2] - 1.0) / 2.0))
    return math.acos(c)


def achar_laco(cin, nomes, min_len, max_len):
    """Acha (inicio, comprimento) em que a pose volta a ser quase a mesma (ciclo de caminhada)."""
    n = len(cin)
    melhor = (1e9, 1, min_len)
    for s in range(1, max(2, n // 3), 2):
        for L in range(min_len, min(max_len, n - s - 1), 2):
            d = 0.0
            for nome in nomes:
                d += _dist_rot(cin[s][0][nome], cin[s + L][0][nome])
            if d < melhor[0]:
                melhor = (d, s, L)
    return melhor[1], melhor[2]


def retargetar_humanoide(arm, bones, zmin, FWD, caminho, nome, laco=True, no_lugar=True, chao="ancorar", fps=30):
    """Cria uma ação `nome` no armature `arm` com o movimento do BVH. `bones` = {nome: (head, tail, pai)} do animar.py."""
    pb = arm.pose.bones
    bvh = ler_bvh(caminho)
    cin = cinematica(bvh)
    nomes_bvh = {j["nome"] for j in bvh["juntas"]}
    # lados do alvo: esquerda = cima x frente
    esq_vec = Vector((0, 0, 1)).cross(FWD)
    # eixos: BVH x=esquerda, y=cima, z=frente  ->  alvo: esquerda, cima, frente
    M = Matrix(((esq_vec.x, 0.0, FWD.x), (esq_vec.y, 0.0, FWD.y), (esq_vec.z, 1.0, FWD.z)))
    Mi = M.inverted()
    # ligação osso do alvo -> junta da fonte
    lig = {}
    for nome_osso in bones:
        base = nome_osso.split(".")[0]
        if base not in MAPA_HUMANOIDE:
            continue
        modelo = MAPA_HUMANOIDE[base]
        if "{S}" in modelo:
            lado_esq = (bones[nome_osso][0] - bones["quadril"][0]).dot(esq_vec) > 0
            modelo = modelo.replace("{S}", "Left" if lado_esq else "Right")
        if modelo in nomes_bvh:
            lig[nome_osso] = modelo
    # ordem pais -> filhos
    ordem = []
    def visita(n):
        if n in ordem:
            return
        p = bones[n][2]
        if p:
            visita(p)
        ordem.append(n)
    for n in bones:
        visita(n)
    rest = {n: arm.data.bones[n].matrix_local.to_3x3() for n in bones}
    rel = {}
    for n in bones:
        p = bones[n][2]
        rel[n] = (rest[p].inverted() @ rest[n]) if p else rest[n]
    # janela do clipe
    ini, comp = 1, len(cin) - 1
    if laco:
        ini, comp = achar_laco(cin, list(set(lig.values())), int(0.8 / bvh["dt"]), min(int(2.4 / bvh["dt"]), len(cin) // 2))
    passo = max(1, round((1.0 / fps) / bvh["dt"]))
    quadros = list(range(ini, ini + comp + (0 if laco else 1), passo))
    if laco:
        quadros.append(ini)
    G0 = cin[0][0]
    raiz0 = cin[0][1]
    alt_fonte = max(abs(raiz0.y), 1e-6)
    alt_alvo = bones["quadril"][0].z - zmin
    esc = alt_alvo / alt_fonte

    pes = [n for n in bones if n.split(".")[0] == "pe"]
    base_pe = min(min(bones[n][0].z, bones[n][1].z) for n in pes) if pes else zmin
    M_arm = arm.matrix_world

    act = bpy.data.actions.new(nome)
    arm.animation_data_create()
    arm.animation_data.action = act
    for p in pb:
        p.rotation_mode = "QUATERNION"
    for idx, f in enumerate(quadros):
        mundo = {}
        for n in ordem:
            if n in lig:
                delta = cin[f][0][lig[n]] @ G0[lig[n]].inverted()
                R = (M @ delta @ Mi) @ rest[n]
            else:
                p = bones[n][2]
                R = (mundo[p] @ rel[n]) if p else rest[n]       # sem fonte: acompanha o pai
            mundo[n] = R
            p = bones[n][2]
            base = (mundo[p] @ rel[n]) if p else rest[n]
            basis = base.inverted() @ R
            pb[n].rotation_quaternion = basis.to_quaternion()
            pb[n].keyframe_insert("rotation_quaternion", frame=idx + 1)
        # movimento do quadril
        d = cin[f][1] - raiz0
        mov = Vector((d.x, d.y, d.z))
        if no_lugar:
            mov = Vector((0.0, mov.y, 0.0))
        mov_alvo = M @ (mov * esc)
        pb["quadril"].location = rest["quadril"].inverted() @ mov_alvo
        if pes:
            # ajuste ao chão: mede o pé mais baixo e corrige a altura do quadril.
            # "ancorar": o pé mais baixo fica exatamente no chão (acaba com pé flutuando/afundado);
            # "minimo": só impede de afundar (preserva o salto da corrida)
            bpy.context.view_layer.update()
            baixo = min(min((M_arm @ pb[n].head).z, (M_arm @ pb[n].tail).z) for n in pes)
            erro = base_pe - baixo
            if chao == "ancorar" or erro > 0:
                mov_alvo.z += erro
                pb["quadril"].location = rest["quadril"].inverted() @ mov_alvo
        pb["quadril"].keyframe_insert("location", frame=idx + 1)
    act.use_fake_user = True
    for p in pb:
        p.rotation_quaternion = Quaternion((1, 0, 0, 0))
        p.location = Vector((0, 0, 0))
    return len(quadros), len(set(lig.values()))
