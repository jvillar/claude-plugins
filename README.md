# claude-plugins

Marketplace personal de plugins para [Claude Code](https://docs.claude.com/en/docs/claude-code).

## Estructura

```
.
├── .claude-plugin/
│   └── marketplace.json     # Manifest del marketplace; lista plugins disponibles
└── plugins/
    └── <plugin-name>/
        ├── .claude-plugin/
        │   └── plugin.json  # Manifest del plugin
        ├── commands/        # Slash commands
        ├── skills/          # Skills
        ├── agents/          # Subagents
        └── hooks/           # Hooks
```

## Añadir el marketplace en Claude Code

```bash
/plugin marketplace add jvillar/claude-plugins
```

(Requiere acceso al repo si es privado: configura un PAT o SSH key en GitHub).

## Crear un plugin nuevo

1. Crea la carpeta `plugins/<nombre>/`.
2. Añade `plugins/<nombre>/.claude-plugin/plugin.json`:
   ```json
   {
     "name": "mi-plugin",
     "version": "0.1.0",
     "description": "Qué hace este plugin"
   }
   ```
3. Mete tus `commands/`, `skills/`, `agents/` o `hooks/` dentro de la carpeta del plugin.
4. Registra el plugin en `.claude-plugin/marketplace.json`:
   ```json
   {
     "plugins": [
       {
         "name": "mi-plugin",
         "source": "./plugins/mi-plugin",
         "description": "Qué hace este plugin"
       }
     ]
   }
   ```
5. Commit + push.

## Instalar un plugin tras añadirlo al marketplace

```bash
/plugin install mi-plugin@jvillar-claude-plugins
```
