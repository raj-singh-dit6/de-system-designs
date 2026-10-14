# SYSTEM DESIGN 1 : Datawarehouse Governance Strategy

This document accompanies [system-design-1.pptx](system-design-1.pptx), a
two-slide proposal for governing application access to the data warehouse.

## Slide 1: Governance model

Slide 1 presents the high-level access pattern:

1. Each application has a dedicated PostgreSQL login user:
   - `analytics_app_user`
   - `sales_app_user`
   - `logistics_app_user`
2. Each login user inherits permissions from one `NOLOGIN` database group:
   - `analytics_app_group`
   - `sales_app_group`
   - `logistics_app_group`
3. Permissions are granted to the database groups, rather than directly to
   application users. This makes access easier to review, change, and revoke.

The slide also summarizes each application's responsibility:

| Application | Responsibility |
| --- | --- |
| Analytics | Read-only sales and membership analysis. |
| Sales | Maintain and safely retire catalogue products. |
| Logistics | View order weights and complete eligible transactions. |

## Slide 2: Database grants matrix

Slide 2 contains the implementation-level permissions for each database group.
It specifies the permitted database objects, SQL-style grants, and explicit
restrictions.

| Database group | Allowed access | Restricted access |
| --- | --- | --- |
| `analytics_app_group` | `SELECT` on the dedicated analytics views. | No data modification, DDL, or base-table access. |
| `sales_app_group` | Add and update products; execute the controlled product-retirement function. | No hard deletes, member access, or sales-fact access. |
| `logistics_app_group` | Read order-weight details; execute the controlled order-completion function. | No direct transaction-table modifications. |

The detailed matrix follows least privilege: views limit analytical read access,
and controlled functions restrict sensitive operational changes to valid
business actions.

## View the slides

Open [system-design-1.pptx](system-design-1.pptx) in PowerPoint, Keynote, or a
compatible presentation application. The deck contains two slides.
