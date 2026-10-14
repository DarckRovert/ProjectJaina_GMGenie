# ❄️ Project Jaina — GMGenie

[![GitHub](https://img.shields.io/badge/GitHub-DarckRovert%2FProjectJaina_GMGenie-black?logo=github)](https://github.com/DarckRovert/ProjectJaina_GMGenie)

> **Project Jaina Ecosystem** · WotLK 3.3.5a compatible · `Interface: 30300`  
> Fork de [Game Master Genie](https://www.curse.com/addons/wow/game-master-genie) por Chocochaos — Adaptado para JainaCore/Project Jaina por DarckRovert

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

Suite completa de herramientas para **Game Masters** de Project Jaina sobre JainaCore. Combina múltiples paneles (tickets, spawns, HUD, disciplina, teleports) en una interfaz unificada diseñada para la gestión eficiente del servidor.

---

## Características

### Gestión de Tickets
- Visualización y respuesta a tickets de jugadores en tiempo real.
- Sistema de categorización y prioridades.

### Sistema de Spawns
- Panel de spawn de NPCs y objetos con coordenadas.
- Base de datos de spawns frecuentes.

### HUD de GM
- Overlay de información del GM visible solo con `.gm on`.
- Estado del servidor, jugadores online, alertas.

### Macros GM
- **Disciplina** — Macros de sanciones (warn, mute, ban).
- **Teleports** — Teletransporte rápido a zonas clave.
- **Mail** — Envío masivo de correos de anuncio.
- **Whispers** — Plantillas de respuesta rápida.

### Spy
- Monitoreo de canales de chat para detección de comportamiento.

---

## Instalación

Solo para cuentas GM en servidores Project Jaina.

1. Copia `GMGenie` a `Interface/AddOns/`.
2. Requiere `.gm on` para acceder a los paneles.
3. Los sub-addons de `Chronos/` se cargan automáticamente.

## 💻 Comandos de Barra (Slash Commands)

| Comando | Acción |
|---|---|
| `/gmgenie` | Alterna la visualización del panel principal de GMGenie. |
| `/gmg` | Abreviatura rápida de apertura y cierre de la suite. |
| `/gmg hud` | Alterna la visualización del overlay HUD de GM. |

## Variables Guardadas

- `GMGenie_SavedVars` — Configuración global, layouts de paneles, macros personalizados.

## Estructura

```
GMGenie/
├── GMGenie.lua         # Core del addon
├── GMGenie.xml         # Frames principales
├── Hud.lua/.xml        # HUD overlay
├── Tickets.lua/.xml    # Sistema de tickets
├── Spawns.lua/.xml     # Panel de spawns
├── Spy.lua/.xml        # Monitor de chat
├── Macros.*.lua        # Módulos de macros
├── Options/            # Paneles de configuración
├── Chronos/            # Librería de timers
└── Textures/           # Recursos gráficos
```

## Créditos y Licencia

- **Autor original:** Chocochaos
- **Adaptación y Hardening Project Jaina:** DarckRovert (Elnazzareno) & Antigravity (Mythos 5)
- **Versión:** 1.3.1
- **Licencia:** [GNU General Public License v3.0](LICENSE)

---

## Documentación del Ecosistema

* [Ficha Técnica Oficial del Ecosistema](ECOSYSTEM_REGISTRY.md)
* [Historial de Cambios](CHANGELOG.md)
* [Aviso Legal y Atribución Upstream](NOTICE.md)
* [Texto Completo de la Licencia GPLv3](LICENSE)

---

*Parte del [ecosistema Project Jaina](https://github.com/DarckRovert)*
