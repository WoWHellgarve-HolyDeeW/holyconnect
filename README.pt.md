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
- **Feito para PCs e portateis Windows 10/11** — depois da gravacao/preparacao inicial do SD, o uso normal e so ligar USB e fazer duplo-clique

## Como Funciona

```
┌─────────────┐    Cabo USB      ┌──────────────┐    Wi-Fi/4G     ┌──────────┐
│  Pi-Star    │◄─────────────────►│  PC Windows  │◄────────────────►│ Internet │
│ 192.168.7.2 │   Rede RNDIS     │ 192.168.7.1  │       NAT       │          │
└─────────────┘                   └──────────────┘                  └──────────┘
```

## Inicio Rapido

### Passo 1: Gravar e preparar o cartao SD no Windows (recomendado, uma vez)

Parte de um cartao SD que possa ser apagado e de uma imagem oficial do Pi-Star descarregada de [pistar.uk](https://www.pistar.uk/downloads/).

1. Insere o cartao SD no PC Windows
2. Descarrega o `.zip` oficial do Pi-Star ou extrai o ficheiro `.img`
3. Extrai o pacote completo do HolyConnect
4. Recomendado: mete o `.zip` ou `.img` do Pi-Star em `holyconnect/pistar-image/`
5. Forma mais simples: faz duplo-clique em `HolyConnect-Run-First.bat`
6. O launcher deteta sozinho se o cartao inserido ja tem Pi-Star. Se sim, abre o `PreparePiStarSD.bat`. Se nao, abre o `FlashPiStarSD.bat`.
7. O helper deteta automaticamente o `.zip` ou `.img`, escolhe sozinho o unico destino USB/SD seguro quando so houver um, grava a imagem no cartao e prepara o primeiro arranque do HolyConnect

O Windows deve pedir privilegios de administrador quando o launcher arranca.

Opcional: o flasher explica logo a diferenca entre uso por USB com PC/portatil e uso standalone/movel com dongle Wi-Fi + hotspot do telemovel, e pode pedir os dados do Wi-Fi antes de gravar. Se preferires, tambem podes meter o teu `wpa_supplicant.conf` em `holyconnect/pistar-image/`. Vai incluido um template em `wpa_supplicant.example.conf`.

### Passo 2: Primeiro arranque no Pi (uma vez)

Volta a colocar o cartao no Pi e arranca uma vez.

Nesse primeiro boot, o Pi corre o instalador localmente, aplica a configuracao permanente do USB gadget e reinicia sozinho.

### Alternativa se o cartao ja tiver uma imagem Pi-Star limpa

Se o cartao ja foi gravado com Pi-Star e so falta o bootstrap do HolyConnect:

1. Insere o cartao SD ja gravado no PC Windows
2. Forma mais simples: faz duplo-clique em `HolyConnect-Run-First.bat`
3. O launcher deve detetar automaticamente a particao boot do Pi-Star e abrir o `PreparePiStarSD.bat`
4. O helper deteta a particao boot do Pi-Star, copia o `install.sh` e prepara os ficheiros de arranque

Nao precisas de editar `cmdline.txt` manualmente no caso normal.

### Passo 3: Ligar ao Windows (uso normal)

Depois da preparacao inicial, o uso do dia a dia fica simples:

1. Copia a pasta `windows/` para o PC alvo (ou pen USB)
2. Liga o Pi ao PC pelo **cabo USB** (porta **DATA** do Pi, nao a PWR)
3. Duplo-clique no **`HolyConnect.bat`**
4. O script faz tudo automaticamente e abre o dashboard do Pi-Star

### Fallback avancado: instalacao manual no Pi

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

E so!

## Estrutura do Projeto

```
holyconnect/
├── START-HERE.txt         # Guia curto de primeiro uso para quem extrai o ZIP
├── HolyConnect-Run-First.bat  # Launcher de primeiro uso num clique para utilizadores nao tecnicos
├── HolyConnect-Run-First.ps1  # Decide sozinho se deve gravar ou apenas preparar o cartao SD
├── FlashPiStarSD.bat      # Flasher num clique para imagem oficial Pi-Star com bootstrap HolyConnect
├── FlashPiStarSD.ps1      # Script de gravacao do SD
├── pistar-image/          # Pasta recomendada para o download oficial .zip ou .img do Pi-Star
│   └── wpa_supplicant.example.conf  # Template opcional de Wi-Fi para o primeiro boot
├── PreparePiStarSD.bat     # Helper para preparar SDs Pi-Star limpos no Windows
├── PreparePiStarSD.ps1     # Script de preparacao do SD
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
| **Gravacao do SD num clique** | `FlashPiStarSD.bat` grava uma imagem oficial do Pi-Star e prepara o cartao para o HolyConnect |
| **Preparacao do SD num clique** | `PreparePiStarSD.bat` prepara um cartao Pi-Star limpo a partir do Windows antes do primeiro boot |
| **Launcher inicial num clique** | `HolyConnect-Run-First.bat` decide automaticamente se deve correr o flasher ou o helper de preparacao |
| **DHCP fallback** | Pi tenta DHCP primeiro, fallback para 192.168.7.2 estatico |
| **Logs persistentes** | Guarda diagnostico detalhado de USB / driver / adaptadores / NAT em `windows/logs/*.log` com fallbacks locais seguros |
| **Pacote de suporte** | As falhas tentam exportar um pacote de diagnostico, e `HolyConnect.ps1 -ExportDiagnostics` gera um quando quiseres |
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

## Matriz de Compatibilidade

Estas linhas sao expectativas operacionais, nao promessas cegas. Nos dongles USB Wi-Fi, o chipset importa mais do que a marca impressa.

### Cenarios Windows

| Cenario | Estado | Comportamento esperado |
|---------|--------|------------------------|
| PC Windows 10/11 limpo com admin | Alvo principal | Totalmente automatico no caso comum, ou instalacao RNDIS guiada uma vez |
| PC com Hyper-V / WSL / Docker / VPNs | Suportado com ressalvas | O acesso USB deve funcionar; a partilha de internet pode reutilizar um NAT `192.168.7.0/24` existente ou ficar local-only |
| Sem privilegios de administrador | Nao suportado | Windows bloqueia por desenho os passos de driver, IP e NAT |
| PC sem internet | Suportado para configuracao local | O Pi-Star fica acessivel por USB, mas updates e reflectores nao vao funcionar |

### Cenarios de Dongle Wi-Fi USB

| Familia de dongle | Estado | Notas |
|-------------------|--------|-------|
| Dongles 2.4 GHz baseados em MT7601U | Bom candidato | Melhor primeira escolha para uso standalone/movel; ainda assim testa o modelo exato |
| Dongles 2.4 GHz baseados em RTL8188EU / RTL8188FTV | Misto | Muitas vezes funcionam, mas as revisoes variam muito entre vendedores |
| Nano dongles dual-band desconhecidos | Risco alto | Evita salvo se ja estiverem validados em Pi-Star; 5 GHz e especialmente inconsistente |

## FAQ

**P: Preciso de portatil para usar o hotspot no carro?**
R: Sim, com HolyConnect precisas de PC/portatil. Considera comprar um dongle Wi-Fi USB para o Pi como alternativa standalone.

**P: E se o IP da internet do PC mudar? (hotspot movel, etc.)**
R: Sem problema. O NAT adapta-se automaticamente. A ligacao Pi↔PC e sempre 192.168.7.x.

**P: Isto modifica o Pi-Star?**
R: Apenas adiciona um servico USB gadget e config de rede. O Pi-Star em si nao e alterado.

**P: Tenho de editar o cmdline.txt manualmente?**
R: Nao no fluxo normal. Usa `PreparePiStarSD.bat` num cartao SD Pi-Star limpo a partir do Windows. Editar o `cmdline.txt` a mao fica apenas como fallback avancado.

**P: Comeco com um cartao SD vazio?**
R: Se usares `FlashPiStarSD.bat`, sim: comecas com um cartao que pode ser apagado e com o ficheiro `.zip` ou `.img` oficial do Pi-Star. Esse helper grava primeiro a imagem Pi-Star e depois adiciona o bootstrap de primeiro arranque do HolyConnect. `PreparePiStarSD.bat` e para cartoes que ja tenham uma imagem Pi-Star limpa gravada.

**P: Onde meto o download do Pi-Star?**
R: A pasta recomendada e `holyconnect/pistar-image/`. O `FlashPiStarSD.bat` tambem procura ao lado da pasta HolyConnect e uma pasta acima. Se ainda assim nao encontrar, abre um seletor de ficheiro ou pede o caminho.

**P: O HolyConnect tambem pode deixar o Wi-Fi preconfigurado?**
R: Sim. No fluxo normal, o flasher pode pedir os dados do Wi-Fi durante a gravacao e gerar o `wpa_supplicant.conf` automaticamente para esse run. Se preferires, tambem podes colocar `holyconnect/pistar-image/wpa_supplicant.conf` manualmente. Isto e opcional e nao e necessario para o modo USB do HolyConnect.

**P: O HolyConnect consegue preparar um Pi-Star stock via USB so com o HolyConnect.bat?**
R: Nao. Um Pi-Star stock tem de ser preparado uma vez pelo cartao SD ou por SSH primeiro, porque o USB gadget ainda nao existe nesse estado inicial.

**P: Primeira vez num PC novo — preciso de instalar drivers manualmente?**
R: Normalmente nao. Os MS OS Descriptors fazem o Windows detetar automaticamente. O HolyConnect agora tambem tenta todos os ficheiros INF RNDIS built-in que encontrar antes de cair na instalacao manual guiada.

**P: Onde vejo logs se um PC novo falhar?**
R: O HolyConnect grava um log com timestamp em `windows/logs/` ao lado do script sempre que puder. Se essa pasta nao for gravavel, usa `%ProgramData%\HolyConnect\logs` ou `%TEMP%\HolyConnect`. O log inclui deteccao USB, tentativas de driver, escolha de adaptador, rotas e estado NAT.

**P: Como gero um pacote de diagnostico para suporte?**
R: As falhas agora tentam exportar automaticamente um pacote de diagnostico para `windows/diagnostics/` (com fallback para `%ProgramData%\HolyConnect\diagnostics` e `%TEMP%\HolyConnect\diagnostics`). Para gerar um pacote mesmo num run com sucesso, abre PowerShell elevada e corre `HolyConnect.ps1 -ExportDiagnostics`.

## Suporte e Bugs

Se abrires issue ou quiseres diagnosticar um PC novo, junta:
- Modelo do Pi e versao do Pi-Star
- Modelo da placa hotspot
- Versao do Windows
- Pacote de diagnostico gerado pelo HolyConnect (ou pelo menos o log)

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) para regras curtas de reporte e detalhes de suporte.

O repositório inclui templates de issue para bugs e relatorios de compatibilidade.

**P: Isto vai mexer nas redes do Hyper-V, Docker, WSL ou VPN?**
R: As versoes atuais nao apagam outras regras NAT do Windows. Se `192.168.7.0/24` ja estiver ocupado, o HolyConnect reutiliza esse NAT quando possivel ou fica em modo local apenas por USB.

**P: E se o auto-detetar escolher o adaptador errado num PC esquisito?**
R: Na maioria dos PCs funciona sozinho. Nos casos limite, corre `HolyConnect.ps1 -InternetAdapterName "Nome do Adaptador"` numa PowerShell elevada.

**P: Posso usar dongle Wi-Fi USB e HolyConnect ao mesmo tempo?**
R: Nao no Pi Zero W para o modo HolyConnect. A mesma porta USB DATA e usada em modo device para o HolyConnect e em modo host para um dongle Wi-Fi externo, por isso tens de escolher um ou outro em cada momento. O processo certo e usar HolyConnect para configurar, desligar o PC e depois trocar essa porta para um adaptador OTG + dongle Wi-Fi para uso standalone.

## Licenca

MIT — ver [LICENSE](LICENSE)

## Creditos

Nasceu de um chip Wi-Fi morto num Pi Zero W e da teimosia de nao desistir de um hotspot MMDVM perfeitamente bom.

73 de HolyConnect!
