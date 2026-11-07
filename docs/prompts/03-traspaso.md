# Traspaso Claude Code → Codex (para quien se quede sin cuota)

Antes de cambiar (si alcanzas): pide al agente "Actualiza tu archivo de progreso con lo hecho, lo que falta de la historia actual y los errores conocidos; haz commit wip y push."
Si ya se cortó: git add -A; git commit -m "wip(<ID>): traspaso"; git push

Abre Codex en la misma carpeta y pega:

Retomas el trabajo de otro agente. Lee AGENTS.md y docs/progreso-<back|front>.md, revisa git status y git log -10, y continúa la cola desde la historia "En curso" respetando sus criterios en docs/backlog.md y las reglas de carpetas de AGENTS.md. Antes de escribir código, resume en 5 líneas qué falta. Estás en Windows con PowerShell. Al terminar: pruebas en verde, actualiza el archivo de progreso, commit, push y PR con gh pr create.

Después se sigue con el mismo prompt de siempre (01-andres-back.md o 02-cesar-front.md).
