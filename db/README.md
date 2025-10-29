# 🌿 EcoTrade — Módulo de Base de Datos

💡 **Proyecto académico** enfocado en la economía circular y la sostenibilidad, que impulsa el intercambio responsable de bienes y servicios mediante créditos verdes.  
La base de datos de este módulo es el núcleo del sistema, garantizando trazabilidad, seguridad e impacto ambiental medible.

---

## 🧭 Descripción General

La base de datos de **EcoTrade** fue diseñada para gestionar de manera eficiente el flujo de información dentro del ecosistema de intercambio sostenible.  
Su arquitectura garantiza integridad referencial, automatización de procesos, registro histórico y control ambiental cuantificable.

Esta base está estructurada en torno a tres pilares fundamentales:

- 👥 **Usuarios y Roles** — Control de autenticación, permisos y balances individuales.  
- 🌱 **Productos e Impacto Ambiental** — Administración de categorías, métricas ecológicas y equivalencias por unidad.  
- 🔄 **Intercambios y Trazabilidad** — Registro transparente de operaciones, créditos y reportes ecológicos diarios.

---

## 🧩 Estructura de Archivos SQL

| Archivo / Carpeta | Descripción |
|------------------|------------|
| `01_schema.sql` | Contiene la estructura general de la base de datos: tablas, relaciones, vistas e índices. |
| `02_functions_and_procedures.sql` | Define funciones y procedimientos almacenados para automatizar procesos internos. |
| `03_triggers.sql` | Implementa los disparadores (triggers) que aseguran la coherencia y consistencia de datos. |
| `04_seeds.sql` | Carga inicial de datos de prueba (usuarios, productos, categorías, equivalencias, etc.). |
| `init/` | Carpeta con scripts que permiten inicializar toda la base en orden secuencial. |

---

## 🧱 Estructura Principal del Esquema

### 🔐 Autenticación y Usuarios
- `roles` → Define los tipos de usuario (común, emprendedor, administrador).  
- `users` → Contiene información personal, credenciales y fecha de registro.  
- `wallets` → Maneja el saldo de créditos verdes asignados a cada usuario.  

### 🛍️ Productos y Métricas Ambientales
- `categories` y `subcategories` → Organización jerárquica de productos sostenibles.  
- `metrics` → Define los tipos de impacto ecológico (CO₂, agua, energía, residuos, pesticidas).  
- `equivalences` → Tabla clave que establece cuánto impacto se evita por cada unidad de producto.  
- `listings` → Publicaciones creadas por los usuarios para intercambio o donación.  

### 🔁 Transacciones y Créditos
- `exchanges` → Registra cada trueque o transacción realizada.  
- `credits_log` → Historial detallado de movimientos de créditos (entrada, salida, bonificaciones).  
- `credit_purchases` → Control de compras de créditos verdes mediante dinero real.  

### 📊 Reportes y Seguridad
- `impact_daily` → Consolida el impacto ecológico diario total de la plataforma.  
- `campaigns` → Campañas activas con bonificaciones temporales o temáticas.  
- `login_attempts` → Registro de intentos fallidos de autenticación (seguridad del sistema).  

---

## 🪞 Vistas Implementadas

### 🧍 `v_user_details`
Proporciona un perfil completo del usuario, combinando su información básica con el rol y balance actual.

```sql
SELECT user_name, email, role_name, current_balance
FROM v_user_details;
```
🌍 v_environmental_impact_summary

Resume el impacto ambiental acumulado por usuario o categoría.
```sql
SELECT user_id, total_co2_saved, total_water_saved, total_energy_saved
FROM v_environmental_impact_summary;
```

⚙️ Tecnologías Utilizadas

Gestor de Base de Datos: PostgreSQL

Lenguaje SQL Estándar: DDL, DML y DCL

Control de Versiones: Git + GitHub

Entorno de Documentación: Markdown (README_DB.md)

Modelo Conceptual y Lógico: MySQL Workbench / Draw.io

📅 Última Actualización

Fecha: 29 de Octubre 2025
