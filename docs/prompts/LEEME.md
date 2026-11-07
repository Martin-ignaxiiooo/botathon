# Cómo arrancar

## César (ahora)
1. Pausa OneDrive o mueve la carpeta a C:\dev\bothaton.
2. En esta carpeta: git init; git add .; git commit -m "chore: contexto y datos iniciales"; git branch -M main
3. gh repo create planbot --private --source . --push   (o crea el repo en GitHub y haz git remote add + git push)
4. Agrega a Andrés y Lucas como colaboradores. Protege main (PR obligatorio, 1 aprobación).
5. Abre claude en esta carpeta y pega 02-cesar-front.md.

## Andrés (en su computador)
1. Instala Git, Node LTS, GitHub CLI, Docker Desktop (o PostgreSQL 16) y Claude Code (npm install -g @anthropic-ai/claude-code).
2. gh repo clone <usuario>/planbot C:\dev\planbot ; cd C:\dev\planbot ; copy .env.example .env (y pon claves)
3. Abre claude y pega 00-andres-fase0-back.md. Al fusionar su PR, sigue con 01-andres-back.md.

## Revisión cruzada
- César revisa los PR de Andrés (SQL); Andrés revisa los PR de César (front). Máximo 30 minutos por revisión.
- Si a alguien se le acaba la cuota de Claude Code: 03-traspaso.md con Codex.

## Lucas
Recibe de César bluePrism\codigo\*.cs para los objetos de Blue Prism (antes de la hora 3) y usa su prompt de ChatGPT.
