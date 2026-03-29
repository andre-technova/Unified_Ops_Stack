# Technova Unified Ops Stack

---

## PT-BR

![Technova](assets/technova-shield.png)

Centralizando service desk, monitoramento, observabilidade e logs em uma única plataforma para a sua operação de TI.

## Visão geral

O **Technova Unified Ops Stack** é um script Bash para implantação automatizada, em um único host Linux Enterprise 9, de uma pilha composta por:

- GLPI
- Zabbix 7.4
- Grafana OSS
- Graylog 7.x
- Apache HTTPD
- PHP 8.3
- MariaDB 12.0
- MongoDB 8.0
- OpenSearch 2.x

O objetivo do projeto é reduzir esforço manual, padronizar entregas técnicas e acelerar a preparação de ambientes laboratoriais, provas de conceito e bases operacionais iniciais.

## Escopo real do script

Com base no comportamento observado no código, o script:

- atualiza o sistema operacional;
- instala dependências-base;
- ajusta o SELinux para `permissive`;
- instala e configura Apache, PHP e MariaDB;
- cria bancos de dados e usuários para GLPI e Zabbix;
- instala o GLPI via CLI;
- instala e configura o Zabbix 7.4;
- instala MongoDB, OpenSearch e Graylog;
- instala o Grafana;
- ajusta o `firewalld`;
- imprime um resumo final com URLs, versões detectadas e credenciais iniciais.

## O que o script não comprova por si só

- TLS/HTTPS configurado de ponta a ponta;
- hardening completo de segurança;
- integração funcional fim a fim entre GLPI, Zabbix, Grafana e Graylog;
- sizing formal de CPU, RAM e disco;
- segregação de workloads para produção.

## Sistemas operacionais suportados

- Oracle Linux 9.x
- Rocky Linux 9.x
- Red Hat Enterprise Linux 9.x

## Arquitetura resumida

![Arquitetura](assets/architecture.png)

## Fluxo resumido de execução

![Fluxo](assets/flow.png)

## Estrutura documental do pacote

Este pacote foi organizado para publicação em repositório GitHub ou repositório corporativo, contendo:

- `README.md` - visão geral do projeto;
- `CHANGELOG.md` - resumo da versão analisada;
- `INSTALL.md` - guia de instalação;
- `POST-INSTALL.md` - guia de pós-instalação e revisão inicial;
- `TROUBLESHOOTING.md` - diagnóstico e resolução de problemas.

## Pré-requisitos

- execução como `root` ou com `sudo`;
- conectividade com a internet;
- DNS funcional;
- saída HTTP/HTTPS para os repositórios e fontes externas usadas pelo script;
- em RHEL, registro RHSM válido ou variáveis `RHSM_ORG_ID` e `RHSM_ACTIVATION_KEY`;
- em ambientes corporativos, opcionalmente:
  - `CORP_CA_CERT_FILE`, `CORP_CA_CERT_B64` ou `CORP_CA_CERT_URL`;
  - `RHSM_PROXY_HOST`, `RHSM_PROXY_PORT`, `RHSM_PROXY_USER`, `RHSM_PROXY_PASS`.

## Execução rápida

```bash
chmod +x Technova_Unified_Ops_Stack_26.03.29-r1.sh
sudo ./Technova_Unified_Ops_Stack_26.03.29-r1.sh
```

## Endereços esperados após a instalação

- GLPI: `http://IP/glpi`
- Zabbix: `http://IP/zabbix`
- Grafana: `http://IP:3000`
- Graylog: `http://IP:9000`

## Credenciais iniciais identificadas no script

- GLPI: `glpi / glpi`
- Zabbix: `Admin / zabbix`
- Grafana: `admin / Grafana@1234`
- Graylog: `admin / Graylog@1234`
- MariaDB root: `root / Root@1234`
- Banco GLPI: `glpiuser / Glpi@1234`
- Banco Zabbix: `zabbix / Zabbix@1234`

> Troque todas as senhas imediatamente após a instalação.

## Pontos críticos de atenção

- O script força `SELINUX=permissive`.
- O OpenSearch é configurado com `plugins.security.disabled=true`.
- O firewall libera HTTP, HTTPS, `10051/tcp`, `3000/tcp` e `9000/tcp`.
- O script libera HTTPS no firewall, mas não configura TLS.
- Parte dos segredos é gravada em `/tmp`.
- A release do GLPI é dinâmica e depende da detecção no GitHub; o fallback interno do script é `10.0.18`.

---

## EN

![Technova](assets/technova-shield.png)

Centralizing service desk, monitoring, observability, and logs into a single platform for your IT operation.

## Overview

**Technova Unified Ops Stack** is a Bash script for automated deployment, on a single Linux Enterprise 9 host, of a stack composed of:

- GLPI
- Zabbix 7.4
- Grafana OSS
- Graylog 7.x
- Apache HTTPD
- PHP 8.3
- MariaDB 12.0
- MongoDB 8.0
- OpenSearch 2.x

The goal of the project is to reduce manual effort, standardize technical deliveries, and speed up the preparation of lab environments, proof-of-concept scenarios, and initial operational foundations.

## Actual scope of the script

Based on the behavior observed in the code, the script:

- updates the operating system;
- installs base dependencies;
- sets SELinux to `permissive`;
- installs and configures Apache, PHP, and MariaDB;
- creates databases and users for GLPI and Zabbix;
- installs GLPI via CLI;
- installs and configures Zabbix 7.4;
- installs MongoDB, OpenSearch, and Graylog;
- installs Grafana;
- adjusts `firewalld`;
- prints a final summary with URLs, detected versions, and initial credentials.

## What the script does not prove on its own

- end-to-end TLS/HTTPS configuration;
- complete security hardening;
- full end-to-end functional integration between GLPI, Zabbix, Grafana, and Graylog;
- formal CPU, RAM, and disk sizing;
- workload segregation for production.

## Supported operating systems

- Oracle Linux 9.x
- Rocky Linux 9.x
- Red Hat Enterprise Linux 9.x

## High-level architecture

![Architecture](assets/architecture.png)

## High-level execution flow

![Flow](assets/flow.png)

## Documentation package structure

This package was organized for publication in a GitHub repository or corporate repository, containing:

- `README.md` - project overview;
- `CHANGELOG.md` - summary of the analyzed version;
- `INSTALL.md` - installation guide;
- `POST-INSTALL.md` - post-installation and initial review guide;
- `TROUBLESHOOTING.md` - diagnosis and troubleshooting guide.

## Prerequisites

- execution as `root` or with `sudo`;
- internet connectivity;
- working DNS;
- HTTP/HTTPS outbound access to the repositories and external sources used by the script;
- on RHEL, a valid RHSM registration or the `RHSM_ORG_ID` and `RHSM_ACTIVATION_KEY` variables;
- in corporate environments, optionally:
  - `CORP_CA_CERT_FILE`, `CORP_CA_CERT_B64`, or `CORP_CA_CERT_URL`;
  - `RHSM_PROXY_HOST`, `RHSM_PROXY_PORT`, `RHSM_PROXY_USER`, `RHSM_PROXY_PASS`.

## Quick execution

```bash
chmod +x Technova_Unified_Ops_Stack_26.03.29-r1.sh
sudo ./Technova_Unified_Ops_Stack_26.03.29-r1.sh
```

## Expected addresses after installation

- GLPI: `http://IP/glpi`
- Zabbix: `http://IP/zabbix`
- Grafana: `http://IP:3000`
- Graylog: `http://IP:9000`

## Initial credentials identified in the script

- GLPI: `glpi / glpi`
- Zabbix: `Admin / zabbix`
- Grafana: `admin / Grafana@1234`
- Graylog: `admin / Graylog@1234`
- MariaDB root: `root / Root@1234`
- GLPI database: `glpiuser / Glpi@1234`
- Zabbix database: `zabbix / Zabbix@1234`

> Change all passwords immediately after installation.

## Critical points of attention

- The script forces `SELINUX=permissive`.
- OpenSearch is configured with `plugins.security.disabled=true`.
- The firewall allows HTTP, HTTPS, `10051/tcp`, `3000/tcp`, and `9000/tcp`.
- The script enables HTTPS in the firewall, but does not configure TLS.
- Some secrets are written to `/tmp`.
- The GLPI release is dynamic and depends on GitHub detection; the script’s internal fallback is `10.0.18`.

---

## ES

![Technova](assets/technova-shield.png)

Centralizando service desk, monitoreo, observabilidad y logs en una sola plataforma para su operación de TI.

## Visión general

**Technova Unified Ops Stack** es un script Bash para la implementación automatizada, en un único host Linux Enterprise 9, de una pila compuesta por:

- GLPI
- Zabbix 7.4
- Grafana OSS
- Graylog 7.x
- Apache HTTPD
- PHP 8.3
- MariaDB 12.0
- MongoDB 8.0
- OpenSearch 2.x

El objetivo del proyecto es reducir el esfuerzo manual, estandarizar las entregas técnicas y acelerar la preparación de entornos de laboratorio, pruebas de concepto y bases operativas iniciales.

## Alcance real del script

Con base en el comportamiento observado en el código, el script:

- actualiza el sistema operativo;
- instala dependencias base;
- ajusta SELinux a `permissive`;
- instala y configura Apache, PHP y MariaDB;
- crea bases de datos y usuarios para GLPI y Zabbix;
- instala GLPI vía CLI;
- instala y configura Zabbix 7.4;
- instala MongoDB, OpenSearch y Graylog;
- instala Grafana;
- ajusta `firewalld`;
- imprime un resumen final con URLs, versiones detectadas y credenciales iniciales.

## Lo que el script no demuestra por sí solo

- configuración TLS/HTTPS de extremo a extremo;
- hardening completo de seguridad;
- integración funcional completa de extremo a extremo entre GLPI, Zabbix, Grafana y Graylog;
- dimensionamiento formal de CPU, RAM y disco;
- segregación de cargas de trabajo para producción.

## Sistemas operativos compatibles

- Oracle Linux 9.x
- Rocky Linux 9.x
- Red Hat Enterprise Linux 9.x

## Arquitectura resumida

![Arquitectura](assets/architecture.png)

## Flujo resumido de ejecución

![Flujo](assets/flow.png)

## Estructura documental del paquete

Este paquete fue organizado para publicarse en un repositorio de GitHub o en un repositorio corporativo, e incluye:

- `README.md` - visión general del proyecto;
- `CHANGELOG.md` - resumen de la versión analizada;
- `INSTALL.md` - guía de instalación;
- `POST-INSTALL.md` - guía de postinstalación y revisión inicial;
- `TROUBLESHOOTING.md` - guía de diagnóstico y resolución de problemas.

## Requisitos previos

- ejecución como `root` o con `sudo`;
- conectividad a internet;
- DNS funcional;
- salida HTTP/HTTPS hacia los repositorios y fuentes externas utilizadas por el script;
- en RHEL, un registro RHSM válido o las variables `RHSM_ORG_ID` y `RHSM_ACTIVATION_KEY`;
- en entornos corporativos, opcionalmente:
  - `CORP_CA_CERT_FILE`, `CORP_CA_CERT_B64` o `CORP_CA_CERT_URL`;
  - `RHSM_PROXY_HOST`, `RHSM_PROXY_PORT`, `RHSM_PROXY_USER`, `RHSM_PROXY_PASS`.

## Ejecución rápida

```bash
chmod +x Technova_Unified_Ops_Stack_26.03.29-r1.sh
sudo ./Technova_Unified_Ops_Stack_26.03.29-r1.sh
```

## Direcciones esperadas después de la instalación

- GLPI: `http://IP/glpi`
- Zabbix: `http://IP/zabbix`
- Grafana: `http://IP:3000`
- Graylog: `http://IP:9000`

## Credenciales iniciales identificadas en el script

- GLPI: `glpi / glpi`
- Zabbix: `Admin / zabbix`
- Grafana: `admin / Grafana@1234`
- Graylog: `admin / Graylog@1234`
- MariaDB root: `root / Root@1234`
- Base de datos GLPI: `glpiuser / Glpi@1234`
- Base de datos Zabbix: `zabbix / Zabbix@1234`

> Cambie todas las contraseñas inmediatamente después de la instalación.

## Puntos críticos de atención

- El script fuerza `SELINUX=permissive`.
- OpenSearch se configura con `plugins.security.disabled=true`.
- El firewall permite HTTP, HTTPS, `10051/tcp`, `3000/tcp` y `9000/tcp`.
- El script habilita HTTPS en el firewall, pero no configura TLS.
- Parte de los secretos se escribe en `/tmp`.
- La versión de GLPI es dinámica y depende de la detección en GitHub; el fallback interno del script es `10.0.18`.
