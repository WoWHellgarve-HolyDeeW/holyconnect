# HolyConnect

**Solucao USB tethering para hotspots Pi-Star MMDVM com Wi-Fi avariado.**

Liga o teu Raspberry Pi Zero W com Pi-Star a um PC ou portatil Windows 10/11 por cabo USB. Sem Wi-Fi necessario.

---

## O Problema

O chip Wi-Fi BCM43430 nos Raspberry Pi Zero W e conhecido por avariar, especialmente nas placas MMDVM de hotspot do AliExpress (PIMMDVM01 e similares). Quando o Wi-Fi morre, perdes todo o acesso ao Pi-Star — sem dashboard, sem SSH, sem configuracao.

## A Solucao

O HolyConnect transforma a porta USB do Pi Zero W num adaptador de rede virtual usando **USB RNDIS via configfs** com **Microsoft OS Descriptors**. Isto significa:

- **Windows deteta automaticamente** como placa de rede (sem instalar drivers na maioria dos PCs)
- **Ligacao estavel 192.168.7.x** entre Pi e PC
- **Partilha de internet via NAT** — Pi-Star liga a reflectores DMR/YSF/D-Star pela internet do PC
- **Pensado para a maioria dos PCs e portateis Windows 10/11** — copia 2 ficheiros e faz duplo-clique

## Como Funciona

```
┌─────────────┐    Cabo USB      ┌──────────────┐    Wi-Fi/4G     ┌──────────┐
│  Pi-Star    │◄─────────────────►│  PC Windows  │◄────────────────►│ Internet │
│ 192.168.7.2 │   Rede RNDIS     │ 192.168.7.1  │       NAT       │          │
└─────────────┘                   └──────────────┘                  └──────────┘
```

## Inicio Rapido

### Passo 1: Instalar no Pi (uma vez)

Copia `pi-setup/install.sh` para a particao `/boot` do cartao SD do Pi-Star, depois arranca com:

**Opcao A — Editar cmdline.txt (mais facil):**
```
# Adiciona ao FIM do /boot/cmdline.txt (na mesma linha, separado por espaco):
systemd.run=/boot/install.sh systemd.run_success_action=reboot systemd.run_failure_action=reboot
```

**Opcao B — Via SSH (se tiveres acesso):**
```bash
sudo bash /boot/install.sh
```

O Pi reinicia automaticamente apos a instalacao.

### Passo 2: Ligar ao Windows

1. Copia a pasta `windows/` para o PC alvo (ou pen USB)
2. Liga o Pi ao PC pelo **cabo USB** (porta **DATA** do Pi, nao a PWR)
3. Duplo-clique no **`HolyConnect.bat`**
4. O script faz tudo automaticamente e abre o dashboard do Pi-Star

E so!

## Conteudo

```
holyconnect/
├── pi-setup/
│   └── install.sh          # Instalador Pi (uma vez)
├── windows/
│   ├── HolyConnect.bat     # Launcher (duplo-clique, auto-admin)
│   └── HolyConnect.ps1     # Script principal
├── README.md               # Versao inglesa
├── README.pt.md            # Este ficheiro
└── LICENSE                 # Licenca MIT
```

## Funcionalidades

| Funcionalidade | Detalhes |
|----------------|----------|
| **Auto-detecao** | Espera pelo Pi, procura em multiplos IPs, verifica tabela ARP |
| **Auto-driver** | Tenta `pnputil` + restart do dispositivo antes de pedir instalacao manual |
| **Internet NAT** | Partilha internet do PC com o Pi via `New-NetNat` sem apagar outras regras NAT |
| **Bilingue** | Deteta idioma do sistema (Ingles / Portugues) |
| **Sem dependencias** | Usa apenas ferramentas built-in do Windows (PowerShell 5.1+) |
| **MS OS Descriptors** | Windows reconhece Pi como RNDIS automaticamente |
| **DHCP fallback** | Pi tenta DHCP primeiro, fallback para 192.168.7.2 estatico |
| **Override de adaptador** | Opcional `-InternetAdapterName` para PCs com VPN, rede empresarial ou varias VMs |

## Compatibilidade

### Lado Pi
- Raspberry Pi Zero W, Zero 2 W (qualquer placa com USB OTG)
- Pi-Star 4.x (testado com 4.2.3)
- Sistemas ao estilo Raspberry Pi OS que usem `/boot`, `systemd`, `dhcpcd` e `dwc2`

### Lado Windows
- Windows 10 (1703+) e Windows 11
- PowerShell 5.1+ (incluido no Windows)
- Requer privilegios de administrador
- Nao precisa de software de terceiros
- Em PCs com Hyper-V, WSL, Docker ou VPNs, o HolyConnect reutiliza um NAT `192.168.7.0/24` existente ou fica em modo local em vez de mexer noutras regras NAT do Windows

### Placas MMDVM Testadas
- PIMMDVM01 (AliExpress)
- ZUMspot
- Outras placas com Pi Zero W devem funcionar

## FAQ

**P: Preciso de portatil para usar o hotspot no carro?**
R: Sim, com HolyConnect precisas de PC/portatil. Considera comprar um dongle Wi-Fi USB para o Pi como alternativa standalone.

**P: E se o IP da internet do PC mudar? (hotspot movel, etc.)**
R: Sem problema. O NAT adapta-se automaticamente. A ligacao Pi↔PC e sempre 192.168.7.x.

**P: Isto modifica o Pi-Star?**
R: Apenas adiciona um servico USB gadget e config de rede. O Pi-Star em si nao e alterado.

**P: Primeira vez num PC novo — preciso de instalar drivers manualmente?**
R: Normalmente nao. Os MS OS Descriptors fazem o Windows detetar automaticamente. Em versoes mais antigas do Windows, o script guia-te pela instalacao manual (uma vez, ~30 segundos).

**P: Isto vai mexer nas redes do Hyper-V, Docker, WSL ou VPN?**
R: As versoes atuais nao apagam outras regras NAT do Windows. Se `192.168.7.0/24` ja estiver ocupado, o HolyConnect reutiliza esse NAT quando possivel ou fica em modo local apenas por USB.

**P: E se o auto-detetar escolher o adaptador errado num PC esquisito?**
R: Na maioria dos PCs funciona sozinho. Nos casos limite, corre `HolyConnect.ps1 -InternetAdapterName "Nome do Adaptador"` numa PowerShell elevada.

## Licenca

MIT — ver [LICENSE](LICENSE)

## Creditos

Nasceu de um chip Wi-Fi morto num Pi Zero W e da teimosia de nao desistir de um hotspot MMDVM perfeitamente bom.

73 de HolyConnect!
