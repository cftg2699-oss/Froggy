# 🐸 Froggy Logs

**Registro automático de todas las interacciones de Froggy**

Este repositorio mantiene un registro centralizado de todas las conversaciones, actividades y reportes generados por Froggy (el asistente AI de FraudEG).

## 📂 Estructura

```
Froggy/
├── logs/
│   ├── YYYY-MM-DD.md      # Log diario legible (resumen + fragmentos)
│   └── YYYY-MM-DD.json    # Log diario en formato procesable
├── sessions/
│   └── <usuario>/
│       └── YYYY-MM-DD.md  # Conversaciones completas por usuario/día
└── scripts/
    └── push-logs.sh        # Script que genera y sube los logs
```

## 🎯 Propósito

- **Transparencia** → Todos los founders pueden ver el historial de actividades
- **Productividad** → Contexto completo para tomar decisiones informadas
- **Trazabilidad** → Registro de qué se hizo, cuándo y con quién

## 🔒 Privacidad

Repositorio privado — solo accesible para founders de FraudEG.

---

_Generado automáticamente por Froggy · Powered by OpenClaw_
