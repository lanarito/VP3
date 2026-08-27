# -*- coding: utf-8 -*-
"""
Regenera HISTORIAL_CHATS.md juntando TODAS las conversaciones de Claude sobre VP3.
Uso:  python actualizar_historial.py
"""
import json, os, glob
from collections import defaultdict

TRANSCRIPCIONES = os.path.expanduser(
    r'~\.claude\projects\c--Github-repos-VP3-COMPLETO')
SALIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'HISTORIAL_CHATS.md')


def texto(d):
    c = d.get('message', {}).get('content')
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return '\n'.join(x.get('text', '') for x in c
                         if isinstance(x, dict) and x.get('type') == 'text')
    return ''


def main():
    filas = []
    for f in glob.glob(os.path.join(TRANSCRIPCIONES, '*.jsonl')):
        for linea in open(f, encoding='utf-8'):
            try:
                d = json.loads(linea)
            except Exception:
                continue
            if d.get('isSidechain') or d.get('type') not in ('user', 'assistant'):
                continue
            s = texto(d).strip()
            ts = d.get('timestamp', '')
            if not s or not ts:
                continue
            if s.startswith('<') or s.startswith('[Request interrupted'):
                continue
            if 'system-reminder' in s[:200]:
                continue
            filas.append((ts, d['type'], s))

    if not filas:
        print('No se encontraron transcripciones en', TRANSCRIPCIONES)
        return
    filas.sort(key=lambda r: r[0])

    por_dia = defaultdict(list)
    for ts, t, s in filas:
        por_dia[ts[:10]].append((ts[11:16], t, s))

    with open(SALIDA, 'w', encoding='utf-8') as out:
        out.write('# 🗂️ HISTORIAL COMPLETO DE CHATS - VP3\n\n')
        out.write('Registro unificado de **todas** las conversaciones de Claude sobre VP3.\n')
        out.write('Generado con `python actualizar_historial.py`.\n\n')
        out.write(f'- **Periodo:** {filas[0][0][:10]} a {filas[-1][0][:10]}\n')
        out.write(f'- **Mensajes:** {len(filas)}\n')
        out.write(f'- **Dias con actividad:** {len(por_dia)}\n\n---\n\n')
        for dia in sorted(por_dia):
            out.write(f'## {dia}\n\n')
            for hm, t, s in por_dia[dia]:
                s = ' '.join(s.split())
                quien = 'LUIS' if t == 'user' else 'CLAUDE'
                limite = 300 if t == 'user' else 500
                if len(s) > limite:
                    s = s[:limite] + ' […]'
                out.write(f'- `{hm}` **{quien}:** {s}\n')
            out.write('\n')

    print(f'OK - {len(filas)} mensajes, {len(por_dia)} dias -> {SALIDA}')


if __name__ == '__main__':
    main()
