# Azure 클라우드 인프라 및 M365 Defender 보안 구축

Azure 클라우드 환경에 Terraform으로 인프라를 자동 프로비저닝하고 M365 Defender 기반 보안을 구성한 프로젝트입니다.

---

## 기술 스택

- **IaC**: Terraform (azurerm 4.74.0)
- **Cloud**: Microsoft Azure
- **보안**: M365 Defender, Azure Key Vault, Bastion
- **네트워크**: VNet, NAT Gateway, VPN Gateway, NSG, Traffic Manager
- **컴퓨팅**: VMSS (Virtual Machine Scale Set), Load Balancer

---

## 인프라 구성

```
├── 00_bootstrap.sh        # 초기 인프라 세팅 (Key Vault, Storage Account)
├── 100_run.sh             # 전체 배포 스크립트
└── 01_tuna/
    ├── 00_init.tf         # Provider 및 Backend 설정
    ├── 01_rg.tf           # Resource Group
    ├── 02_vnet1.tf        # VNet 1 (Region 1)
    ├── 03_vnet2.tf        # VNet 2 (Region 2)
    ├── 04_pubip.tf        # Public IP
    ├── 05_bastion.tf      # Azure Bastion
    ├── 06_nsg.tf          # Network Security Group
    ├── 07_natgw.tf        # NAT Gateway
    ├── 09_vpn_gateway.tf  # VPN Gateway
    ├── 10_dns.tf          # DNS 설정
    ├── 11_load1.tf        # Load Balancer 1
    ├── 12_load2.tf        # Load Balancer 2
    ├── 13_vmss1.tf        # VM Scale Set 1
    ├── 14_vmss2.tf        # VM Scale Set 2
    ├── 15_traffic_manager.tf  # Traffic Manager
    ├── 16_keyvault.tf     # Key Vault
    ├── 17_keyvault_policy.tf  # Key Vault 접근 정책
    ├── 18_identity.tf     # Managed Identity
    └── 100_var.tf         # 변수 정의
```

---

## 실행 방법

```bash
# 1. SUBSCRIPTION_ID 환경변수 설정
export SUBSCRIPTION_ID="구독ID"

# 2. terraform.tfvars 수정 (본인 환경에 맞게)
#    - rgname        : 생성할 리소스 그룹명
#    - key_vault_name: 전역 고유값이므로 반드시 변경
#    - loca1, loca2  : 배포할 Azure 지역
vi 01_tuna/terraform.tfvars

# 3. 전체 배포 (bootstrap → Terraform 순서로 자동 실행)
bash 100_run.sh
```

---

## 주요 보안 구성

- **Azure Bastion**: 공개 IP 없이 VM 안전 접속
- **Key Vault**: 시크릿(DB 정보 등) 중앙 관리, Managed Identity로 접근
- **NSG**: 트래픽 화이트리스트 기반 제어
- **M365 Defender**: 엔드포인트 위협 탐지 및 대응
- **tfstate 원격 저장**: Azure Storage Account로 상태 파일 중앙 관리
