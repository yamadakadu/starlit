# Arquitetura do provisionamento

Visão geral do processo: da preparação do servidor até a última etapa definida nas [etapas](etapas/index.md).

Cores: azul = roda no servidor; verde = roda na placa; amarelo = passo manual; branco = pendente ou rede.

```mermaid
flowchart TB
    subgraph S1["1 · No servidor: uma vez, como root (sudo), na ordem"]
        direction LR
        A0["<b>Preparar o servidor (à mão)</b><br/>Ubuntu 24.04, IP que não muda<br/>clonar/copiar o repositório + cluster-key.pub<br/>config.env (de config.env.example): IP, INTERFACE, REDE<br/>(hoje: notebook .216, temporário)"]
        A3["<b>Etapa 3</b><br/>servidor/configurar-servidor.sh<br/>dnsmasq: proxy DHCP + TFTP<br/>nginx: HTTP em /srv/http"]
        A2["<b>Etapa 2</b><br/>imagem/preparar-imagem.sh<br/>cloud image + kernel generic<br/>→ noble.raw.gz (~1,7 GB)<br/>publicar-cloud-init.sh → user-data, meta-data"]
        A4["<b>Etapa 4</b><br/>ipxe/preparar-ipxe.sh<br/>compila ipxe.efi (snponly)<br/>baixa o Alpine, gera boot.ipxe"]
        A5["<b>Etapa 5</b><br/>alpine/empacotar-apkovl.sh<br/>→ starlit.apkovl.tar.gz (starlit.start)"]
        A0 --> A3 --> A2 --> A4 --> A5
    end

    PUB[("<b>O servidor publica</b><br/>TFTP: ipxe.efi<br/>HTTP: boot.ipxe · alpine/ (vmlinuz, initramfs, modloop, apkovl)<br/>noble.raw.gz · cloud-init/user-data<br/>/phone-home/ → phone-home.log")]
    S1 --> PUB

    subgraph S2["2 · Em cada placa: boot pela rede, automático"]
        direction TB
        B1["<b>BIOS (PXE IPv4)</b><br/>IP vem do roteador<br/>proxy DHCP indica o bootloader"]
        B2["<b>ipxe.efi</b> via TFTP<br/>script embutido: dhcp + chain boot.ipxe"]
        B3["<b>Alpine na RAM</b> via HTTP<br/>kernel + initramfs + apkovl<br/>roda starlit.start"]
        B4{"/etc/starlit-release<br/>já está na eMMC?"}
        B4S["<b>Já instalada</b><br/>não grava nada<br/>reinstalar: só à mão (wipefs)"]
        B5["<b>Grava a eMMC</b><br/>noble.raw.gz → mmcblk0<br/>efibootmgr: eMMC 1º no boot<br/>reboot"]
        B6["<b>1º boot do Ubuntu (eMMC)</b><br/>cloud-init busca user-data<br/>usuário ubuntu + chave SSH, sudo sem senha"]
        B7["<b>phone_home</b><br/>avisa o servidor → phone-home.log (IP da placa)"]
        B1 --> B2 --> B3 --> B4
        B4 -- sim --> B4S
        B4 -- não --> B5 --> B6 --> B7
    end

    PUB --> B1

    subgraph S3["3 · Parte 2: registro e cluster"]
        direction LR
        C6["<b>Etapa 6 · Registro (à mão)</b><br/>MAC no log do dnsmasq<br/>reserva MAC→IP no roteador (a confirmar)<br/>hostname up-NN por SSH<br/>anotar no inventario.md"]
        C7["<b>Etapa 7 · Cluster</b><br/>ainda não definida<br/>(Ansible sugerido, não decidido)"]
        C6 --> C7
    end

    B7 --> C6

    subgraph NET["Rede 192.168.0.0/24"]
        direction LR
        R["<b>Roteador TL-R470T+</b><br/>192.168.0.1<br/>DHCP + internet<br/>portas 100 Mbps"]
        SW["<b>Switch DGS-1210-28</b><br/>192.168.0.2 · gigabit<br/>servidor + placas"]
        R --- SW
    end

    classDef servidor fill:#dbe8fb,stroke:#3b6fb6,color:#111
    classDef placa fill:#dcf2df,stroke:#3c8a4a,color:#111
    classDef manual fill:#fff3b0,stroke:#b59a1a,color:#111
    classDef neutro fill:#ffffff,stroke:#888,color:#111

    class A3,A2,A4,A5,PUB servidor
    class B1,B2,B3,B4,B5,B6,B7 placa
    class A0,C6 manual
    class B4S,C7,R,SW neutro
```
