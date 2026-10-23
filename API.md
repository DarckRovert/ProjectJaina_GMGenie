# 🔌 Especificación Técnica y API — ProjectJaina_GMGenie

[![GitHub](https://img.shields.io/badge/GitHub-DarckRovert%2FProjectJaina_GMGenie-black?logo=github)](https://github.com/DarckRovert/ProjectJaina_GMGenie)
[![Ecosistema](https://img.shields.io/badge/Ecosistema-Project%20Jaina%203.3.5a-gold.svg)](https://darckrovert.github.io/ProjectJaina_Web/)

## 📌 Resumen Arquitectónico
Herramienta integral de soporte y administración para GMs con gestión de tickets, teletransporte, inspección silenciosa de jugadores y despacho protegido de comandos.

- **Rol en el Ecosistema:** Módulo Oficial #6 — Herramientas Staff / GM
- **Archivo Principal TOC:** `ProjectJaina_GMGenie.toc`
- **Compatibilidad del Motor:** World of Warcraft 3.3.5a (Build 12340)

---

## ⌨️ Comandos de Consola (Slash Commands)
- `/jainagm`, `/staff`, `/control`, `/gm`: Alterna el Panel de Control JainaGM (5 pestañas).
- `/gmgenie`, `/gmg`: Alterna el panel de tickets y herramientas base de GMGenie.
- `/gmg hud`: Alterna el HUD superior de monitoreo GM.
- `/wgm`, `/wanigm`: Alias de compatibilidad pasiva para el Panel de Control.
- `/tickets`, `/spawns`, `/builder`, `/spy`: Accesos directos a submódulos.

---

## 📡 Protocolo de Red y Eventos
- `GMGenie_Sync`: Prefijo registrado para sincronización de datos entre GMs.
- `GMGenie_TicketSync`: Prefijo registrado para sincronización de tickets de soporte.

### Eventos del Motor 3.3.5a Gestionados
- `PLAYER_LOGIN` / `ADDON_LOADED`: Inicialización atómica de tablas de configuración y migración de base de datos.
- `PLAYER_ENTERING_WORLD`: Sincronización de estado tras transiciones de pantalla o mapa.
- `PLAYER_LOGOUT`: Guardado seguro en disco de las variables locales.

---

## 💾 Persistencia de Datos (SavedVariables)
- `GMGenie_SavedVars`: Almacenamiento estructurado de tickets, spawns y layouts.
- `JainaGM_DB`: Almacenamiento persistente del Panel de Control (pestaña activa, velocidad, teletransporte grupal).

---

## 🧩 API Pública para Integración
- `GMGenie.ControlPanel.Toggle()`: Alterna la apertura/cierre del Panel de Control.
- `GMGenie.ControlPanel.Show()` / `GMGenie.ControlPanel.Hide()`: Control explícito de visibilidad.
- `_G["JainaGM_Toggle"]`: Función puente en el entorno global para macros o interfaces externas.

---

## 🛠️ Buenas Prácticas de Integración
1. Toda invocación a funciones públicas debe verificar previamente la existencia del espacio de nombres en `_G`.
2. Las tablas de configuración deben consultarse en modo lectura sin sobreescribir valores por omisión no validados.
3. El intercambio de datos con otros addons debe efectuarse a través del bus oficial `ProjectJaina_Companion` o hooks de eventos estándar.
