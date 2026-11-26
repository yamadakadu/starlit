# 1. Rede: roteador, switch e internet

## 1.1 Plano de endereços

Antes de configurar qualquer coisa, decidir os endereços da rede privada. Exemplo, com a rede `192.168.0.0/24`:

| Endereço | Uso | Como é atribuído |
|---|---|---|
| `192.168.0.1` | roteador | fixo (padrão do roteador) |
| `192.168.0.2` | switch | fixo, configurado no switch |
| faixa de DHCP do roteador (ex.: `.20` a `.99`) | notebooks, celulares, outros aparelhos | DHCP automático |
| um IP fora da faixa de DHCP (nesta instalação, `.110`) | servidor | IP fixo no próprio servidor (netplan) |
| `.201` a `.2NN` | placa NN | reserva por MAC no roteador |
| um IP livre (ex.: `.250`) | notebook usado como servidor temporário (opcional, [seção 3](3-servidor.md)) | IP fixo no notebook |

Regras:

- os IPs fixos e reservados **ficam fora** da faixa de DHCP automático, para o roteador não entregá-los a outro aparelho;
- **o IP do servidor não pode mudar depois** que os scripts rodarem: ele fica gravado no iPXE, no `boot.ipxe`, na imagem e no script de gravação. Trocá-lo exige rodar todos os scripts de novo;
- nenhum IP pode coincidir com outro (ex.: um notebook em `.216` colide com a placa 16).

Anotar o plano no `inventario.md`.

## 1.2 Cabeamento

```
internet (rede da instituição) ──> porta WAN do roteador
roteador (porta LAN) ──> switch
servidor e placas ──> switch (portas gigabit)
```

As portas do roteador são de 100 Mbps: ele só leva o tráfego da internet. Servidor e placas ficam sempre no **switch**, que é gigabit.

O TL-R470T+ tem mais de uma porta WAN (multi-WAN). Ver na interface web qual WAN está com status *Connected*: é por ela que a internet sai.

## 1.3 Reset e configuração do roteador (TP-Link TL-R470T+)

1. Reset: com o roteador ligado, segurar o botão **RESET** até os LEDs piscarem (*tempo a confirmar*, normalmente alguns segundos).
2. Ligar um computador numa porta LAN e acessar `http://192.168.0.1`. *Usuário e senha padrão a confirmar na etiqueta do equipamento* (nos modelos TP-Link dessa linha costuma ser `admin` / `admin`). Trocar a senha no primeiro acesso.
3. **WAN:** tipo de conexão *Dynamic IP* (o IP vem da rede da instituição). A tela de status da WAN mostra o IP, o gateway e os **DNS** recebidos; anotar os DNS, eles serão usados no servidor ([seção 3.4](3-servidor.md)).
4. **LAN:** manter `192.168.0.1` / `255.255.255.0`.
5. **Servidor DHCP:** ativado, com a faixa do plano (ex.: `.20` a `.99`).
6. **Reserva de IP por MAC:** é onde entram as placas ([seção 6](6-acesso.md)). *Confirmar o nome do menu e se o roteador aceita reserva fora da faixa de DHCP.*

## 1.4 Reset e configuração do switch (D-Link DGS-1210-28)

1. Reset: com o switch ligado, segurar o botão **Reset** por cerca de 10 segundos (*a confirmar*).
2. Depois do reset, o switch volta ao IP padrão da D-Link, `10.90.90.90/8`, usuário `admin` sem senha (*a confirmar na etiqueta*). Para acessá-lo, ligar um computador direto no switch com um IP fixo temporário na mesma rede (ex.: `10.90.90.100/8`) e abrir `http://10.90.90.90`.
3. Mudar o IP de gerenciamento para o do plano: `192.168.0.2`, máscara `255.255.255.0`, gateway `192.168.0.1`. Trocar a senha.
4. Não é preciso configurar VLANs: todas as portas ficam na VLAN padrão.
5. Voltar o computador para DHCP e conferir o acesso em `http://192.168.0.2`.

## 1.5 Teste da rede

De um computador ligado no switch, por cabo:

```sh
ping -c3 192.168.0.1          # roteador
ping -c3 192.168.0.2          # switch
ping -c3 1.1.1.1              # internet por IP
nslookup ubuntu.com           # DNS
```

Se o ping para `1.1.1.1` funciona e o `nslookup` falha, o problema é o DNS: ver a [seção 3.4](3-servidor.md).

Atenção, num notebook com Wi-Fi e cabo ao mesmo tempo: o DNS pode estar indo pelo Wi-Fi, e o teste passa mesmo com o DNS da rede cabeada quebrado. Para testar só a rede do switch, desligar o Wi-Fi durante o teste.
