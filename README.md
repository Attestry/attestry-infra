# Attestry Infrastructure 

Terraform, EKS, ArgoCD, Kafka, Redis, RDS, Prometheus/Grafana 기반으로 구성한 AWS 인프라 저장소입니다.  
단순 배포 스크립트 모음이 아니라, 실제 운영을 염두에 두고 네트워크 분리, 워크로드 격리, GitOps, 이벤트 처리, 관측성까지 일관되게 설계한 점을 보여주는 것을 목표로 했습니다.

## Executive Summary

- AWS `ap-northeast-2`에 3-AZ VPC, EKS, RDS, S3, SQS, Lambda, SES를 Terraform으로 구성했습니다.
- 애플리케이션 배포는 ArgoCD App-of-Apps 패턴으로 GitOps화했습니다.
- 상태 저장 워크로드인 Kafka는 Strimzi + KRaft 기반으로 운영하며, 전용 노드 그룹과 taint/toleration으로 격리했습니다.
- Core / Ledger 서비스는 Kubernetes에서 운영하고, Redis, PostgreSQL, Kafka와 연결되는 이벤트 기반 구조를 구성했습니다.
- Prometheus, Grafana, Loki, Alert rule, ServiceMonitor까지 포함해 운영 관측 기반을 함께 설계했습니다.

## What This Repository Shows

이 저장소는 아래 역량을 한 번에 보여주기 위해 구성했습니다.

- IaC로 AWS 리소스를 재현 가능하게 관리하는 능력
- Kubernetes 운영 관점에서 워크로드를 분리하고 배포 구조를 단순화하는 능력
- 이벤트 드리븐 아키텍처를 인프라 수준에서 안정적으로 수용하는 능력
- GitOps를 통해 변경 이력, 배포 일관성, 복구 가능성을 높이는 능력
- 운영 환경에서 필요한 메트릭, 로그, 알람 기준까지 설계하는 능력

## Architecture At A Glance

```text
Internet
  -> ALB
  -> EKS Ingress
  -> Services (core / ledger)
  -> Pods

core / ledger
  -> RDS PostgreSQL
  -> Redis
  -> Kafka
  -> S3
  -> SQS

SQS
  -> Lambda
  -> SES

GitHub
  -> attestry-infra
  -> ArgoCD
  -> Kubernetes sync
```

핵심적으로는, 애플리케이션은 EKS에서 실행하고 데이터는 RDS/Redis로 분리하며, 비동기 이벤트는 Kafka, 외부 알림은 SQS + Lambda + SES로 처리하는 구조입니다.

## Technical Scope

| Area | Stack |
|---|---|
| IaC | Terraform |
| Cloud | AWS VPC, EKS, RDS, S3, SQS, Lambda, SES, ACM |
| Orchestration | Kubernetes 1.29 on EKS |
| GitOps | ArgoCD |
| Streaming | Apache Kafka 4.2.0, Strimzi, KRaft |
| Cache | Redis |
| Database | PostgreSQL 16.10 |
| Observability | Prometheus, Grafana, Loki, Alert rules |
| Load Test | k6 |

## Key Design Decisions

### 1. 3-Tier VPC

- Public / Private / Database subnet을 분리했습니다.
- EKS worker node는 private subnet에 배치하고, 외부 진입은 ALB만 담당하게 했습니다.
- NAT Gateway는 단일 구성으로 두어 비용을 통제했습니다.

이 선택은 "완전한 운영형 고가용성"보다 "운영 구조를 유지하면서도 비용을 설명 가능하게 통제하는 환경"에 초점을 둔 판단입니다.

### 2. Workload Isolation On EKS

- 앱 워커와 Kafka 워커를 별도 managed node group으로 분리했습니다.
- Kafka 전용 노드에는 `dedicated=kafka:NoSchedule` taint를 적용했습니다.
- EBS CSI Driver를 사용해 상태 저장 워크로드의 볼륨 프로비저닝을 표준화했습니다.

이렇게 분리하면 상태 저장 워크로드와 일반 애플리케이션 워크로드의 리소스 간섭을 줄이고, 장애 분석과 운영 책임 범위를 더 명확하게 가져갈 수 있습니다.

### 3. GitOps As Deployment Control Plane

- ArgoCD `app-of-apps`로 전체 클러스터 리소스를 선언적으로 관리합니다.
- `prune`와 `selfHeal`을 활성화해 Git과 실제 클러스터 상태를 자동으로 일치시킵니다.
- 서드파티 컴포넌트는 Helm, 자체 애플리케이션은 Kustomize로 분리해 관리합니다.
- polling 대신 webhook 방식으로 Git 변경을 즉시 감지하도록 구성했습니다.

핵심 의도는 "배포"를 사람이 기억하는 절차가 아니라, Git 상태를 기준으로 재현 가능한 시스템 동작으로 바꾸는 것입니다.

### 4. Kafka For Event-Driven Flow

- Strimzi Operator 기반으로 Kafka를 Kubernetes 리소스처럼 관리합니다.
- ZooKeeper 없는 KRaft 모드를 선택해 운영 복잡도를 줄였습니다.
- 브로커는 3대로 구성하고, 복제/ISR/DLQ 전략을 통해 장애 시 메시지 유실 가능성을 낮추는 방향으로 설계했습니다.

이 저장소에서 Kafka는 단순 메시지 브로커가 아니라, 서비스 간 비동기 처리와 데이터 전파를 위한 핵심 인프라 계층입니다.

### 5. Operational Observability

- `ServiceMonitor`로 core / ledger 메트릭을 수집합니다.
- PrometheusRule에 5xx 증가, Pod 재시작, OOMKilled, DB pool 이상, outbox failure, projection lag 등의 알람 기준을 정의했습니다.
- 단순 "대시보드 구성" 수준이 아니라, 장애 징후를 조기에 식별할 수 있는 운영 신호를 문서화했습니다.


## Repository Structure

```text
.
├── terraform/                # AWS 인프라 IaC
├── k8s-manifests/
│   ├── argocd/               # App-of-Apps 및 ArgoCD Application
│   ├── apps/                 # core / ledger Kubernetes manifest
│   ├── infrastructure/       # Kafka, Redis 등 공용 인프라
│   └── monitoring/           # ServiceMonitor, PrometheusRule, Grafana dashboards
├── scripts/                  # 운영 보조 스크립트
├── k6/                       # 부하 테스트 시나리오
└── *.md                      # 아키텍처, 핸드오프, 운영 문서
```

## Operating Principles

이 저장소에서 특히 강조한 운영 원칙은 아래와 같습니다.

- Git을 single source of truth로 둔다
- 상태 저장 워크로드는 일반 앱과 분리한다
- 네트워크, 스토리지, 배포, 알람 기준을 함께 설계한다
- "구성했다"에서 끝내지 않고 "장애 시 어떻게 보일지"까지 고려한다

