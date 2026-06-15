# 🌳 Workflow de desarrollo

Cómo trabajamos los cambios en este repo: Git Flow simplificado + Issues + Pull Requests.

---

## 📌 Reglas de oro

1. **`main` es sagrada** — nunca se commitea directamente, solo entra código via Pull Request mergeado
2. **Cada cambio nace de un Issue** — antes de codear, abre un issue describiendo qué se hace y por qué
3. **Una rama por issue** — el nombre de la rama referencia el issue
4. **Pull Request siempre** — incluso si trabajas solo, abre PR para tener historial revisable
5. **Commit por avance, no por archivo** — agrupa cambios coherentes en un solo commit

---

## 🔁 Flujo paso a paso

```
1. Abrir issue          gh issue create --title "..." --label "..." --body "..."
        │
        ▼
2. Crear rama           git checkout main && git pull
                        git checkout -b feature/nombre-corto
        │
        ▼
3. Codear + commits     git add archivos
                        git commit -m "feat: ..."
        │
        ▼
4. Push rama            git push -u origin feature/nombre-corto
        │
        ▼
5. Abrir PR             gh pr create --base main --head feature/nombre-corto
                        --title "feat: ..." --body "Closes #N"
        │
        ▼
6. Review + merge       gh pr merge N --merge --delete-branch
        │               (cierra issue #N automáticamente por "Closes #N")
        ▼
7. Volver a main        git checkout main && git pull
```

---

## 🏷️ Convenciones de nombres

### Ramas

| Prefijo | Para qué | Ejemplo |
|---------|----------|---------|
| `feature/` | Nueva funcionalidad | `feature/vales-trabajadores` |
| `fix/` | Corrección de bug | `fix/secrets-to-env` |
| `docs/` | Solo documentación | `docs/api-spec` |
| `refactor/` | Reorganizar sin cambiar comportamiento | `refactor/api-client` |
| `chore/` | Mantenimiento (deps, scripts) | `chore/upgrade-flutter` |

**Reglas del nombre:**
- Todo en minúsculas
- Palabras separadas por guion (`-`)
- Corto pero descriptivo (3-5 palabras max)
- Sin tildes ni espacios

### Commits (Conventional Commits)

Formato: `tipo(scope opcional): descripcion en imperativo`

```
feat: agregar sistema de vales con 2 tipos (cash/nombrado)
feat(pos): permitir pago mixto en una sola venta
fix: corregir Navigator.pop en dialogo Yape
fix(api): retornar 404 cuando proveedor no existe
refactor: extraer lógica de descuento a service compartido
docs: actualizar PLAN_ENTREGA con alcance de Karina
chore: actualizar dependencias de Flutter
test: agregar tests de UsuarioService
```

**Tipos comunes:**
| Tipo | Cuándo usar |
|------|-------------|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `refactor` | Cambio interno sin afectar comportamiento |
| `docs` | Solo documentación |
| `test` | Solo tests |
| `chore` | Mantenimiento, deps, configuración |
| `style` | Formato (espacios, comas) — sin cambio de lógica |
| `perf` | Mejora de rendimiento |

### Issues

Mismo formato del commit: `tipo: descripción`. Etiquetas:

| Label | Color | Uso |
|-------|-------|-----|
| `backend` | verde | Cambios en Spring Boot |
| `frontend` | azul | Cambios en Flutter |
| `database` | morado | Esquema de BD / migraciones Flyway |
| `security` | rojo | Vulnerabilidades / hardening |
| `priority-high` | rojo claro | Urgente |
| `bug` | rojo (default) | Reporte de bug |
| `enhancement` | celeste (default) | Mejora |

---

## 🔗 Vinculación issue ↔ PR

En el cuerpo del PR usa **palabras clave** para cerrar el issue al mergear:

```
Closes #1          (cierra issue 1)
Fixes #2           (cierra issue 2)
Resolves #3        (cierra issue 3)
Closes #1, #2, #3  (cierra varios)
```

GitHub auto-cierra el issue cuando el PR se mergea a `main`.

---

## 🧪 Antes de abrir un PR

Checklist mínima:

- [ ] `flutter analyze` sin **errores** (info/warnings de estilo OK)
- [ ] `mvn compile` exitoso (si tocaste backend)
- [ ] La app arranca y la funcionalidad nueva se ve
- [ ] No hay credenciales / secretos en el código
- [ ] El commit tiene mensaje claro siguiendo el formato
- [ ] El cuerpo del PR explica el QUÉ y el POR QUÉ

---

## 📊 Estado actual del proyecto

Ver estado de issues y PRs:

```bash
# Listar issues abiertas
gh issue list

# Ver una issue
gh issue view 2

# Listar PRs
gh pr list

# Ver un PR
gh pr view 7
```

O abrir en navegador: https://github.com/Jesus123J/store_subcafe/issues

---

## 🗂️ Tablero de progreso (a fecha actual)

### ✅ Completado
- **#1 [security]** Mover secretos a variables de entorno (PR #7 mergeado)

### 🟡 Backlog priorizado por orden de implementación
1. **#4 [priority-high]** Pago Mixto en POS (afecta arquitectura de ventas, ir primero)
2. **#2** Sistema de Vales para Trabajadores
3. **#3** Sistema de Puntos por Consumo
4. **#5** Importar trabajadores del sistema viejo
5. **#6** Pantalla de Configuración

### 🤔 Por qué ese orden
- **Pago mixto primero**: cambia la estructura de la tabla `ventas` (de 1 forma de pago a N). Si lo dejamos al final, hay que reescribir lo que se haga antes
- **Vales y puntos después**: se montan encima del pago mixto (vales y puntos son formas de pago adicionales)
- **Import y configuración al final**: son pantallas adicionales que no afectan al resto

---

## 🆘 Si algo sale mal

### Cometí un cambio en `main` por error
```bash
# Mover el último commit a una rama nueva
git branch feature/lo-que-iba-aqui
git reset --hard HEAD~1
git checkout feature/lo-que-iba-aqui
```

### Mi PR tiene conflictos con main
```bash
git checkout feature/mi-rama
git fetch origin main
git rebase origin/main
# Resolver conflictos en los archivos, luego:
git add archivos-resueltos
git rebase --continue
git push --force-with-lease
```

### Quiero descartar una rama
```bash
git checkout main
git branch -D feature/rama-a-borrar
git push origin --delete feature/rama-a-borrar
```

---

## 🔐 Reglas de seguridad

- ❌ **NUNCA** subir archivos `.env`, `application-local.yml`, `*.key`, `*.pem`
- ❌ **NUNCA** hardcodear contraseñas, tokens o API keys
- ✅ Usar variables de entorno con defaults seguros para dev
- ✅ Si un secreto se filtró, **revocarlo y rotarlo** (no basta con eliminarlo del repo)

---

## 📞 Comandos rápidos cheat sheet

```bash
# Ver issues abiertas
gh issue list

# Crear issue rápido
gh issue create --title "..." --body "..." --label "backend"

# Arrancar nueva feature
git checkout main && git pull
git checkout -b feature/nombre

# Commit + push
git add .
git commit -m "feat: ..."
git push -u origin feature/nombre

# Crear PR vinculado al issue
gh pr create --title "feat: ..." --body "Closes #N"

# Mergear PR y borrar rama
gh pr merge --merge --delete-branch
```
