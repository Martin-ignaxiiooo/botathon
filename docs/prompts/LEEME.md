# Prompts por IA (versión vigente)

| Archivo | Quién | Herramienta | Carpeta |
|---|---|---|---|
| 10-cesar-claude-sonnet.md | César | Claude Code · Sonnet | bothaton (front: web\) |
| 11-cesar-codex-gptsol.md | César | Codex · GPT Sol alto | bothaton-codex (C#, bases de prueba, CI, README) |
| 12-andres-claude.md | Andrés | Claude Code · Sonnet (Opus/alto en B-05 y B-06) | C:\dev\planbot (base de datos) |
| 13-lucas-chatgpt.md | Lucas | ChatGPT | VM de Blue Prism |
| 03-traspaso.md | Quien se quede sin cuota | Codex | la misma carpeta |

Cada archivo trae un ARRANQUE (se pega una vez al inicio) y un prompt por historia (se pega al empezar cada una, después de /clear).

## Arranque de César (PowerShell)
1. Pausa OneDrive. 2. En bothaton: git init; git add .; git commit -m "chore: contexto"; git branch -M main; git worktree add ..\bothaton-codex -b codex/trabajo main
3. Pestaña 1: cd bothaton; claude → ARRANQUE de 10. Pestaña 2: cd ..\bothaton-codex; codex → ARRANQUE de 11.
4. Comprime la carpeta bothaton en .zip y mándasela a Andrés (y 13-lucas-chatgpt.md a Lucas).

## Juntar el trabajo (sin GitHub)
- Codex → main: en bothaton, git merge codex/trabajo
- Andrés → César: Andrés manda .zip de database\, api\, scripts\, docker-compose.yml; César los copia en bothaton y hace commit.
- Cuando exista GitHub: git remote add origin <url>; git push -u origin --all
