# 4. Repositório e config.env no servidor

## 4.1 Copiar o repositório

Se o servidor tem acesso ao repositório no GitHub:

```sh
git clone git@github.com:yamadakadu/starlit.git ~/starlit
```

O repositório é acessado por SSH: o servidor precisa de uma chave cadastrada no GitHub. Sem isso, copiar do computador:

```sh
scp -r starlit ubuntu@<IP do servidor>:
```

## 4.2 Criar e preencher o `config.env`

O `config.env` não vai para o git, porque depende da rede de cada instalação. Ele é criado a partir do modelo:

```sh
cd ~/starlit
cp config.env.example config.env
nano config.env
```

Campos obrigatórios (os scripts param com erro se algum estiver vazio):

| Campo | O que é | Exemplo |
|---|---|---|
| `SERVIDOR_IP` | IP fixo do servidor ([seção 3.4](3-servidor.md)) | `192.168.0.110` |
| `INTERFACE` | nome da interface de rede do servidor (`ip -br link`) | `enp1s0` |
| `REDE` | endereço da rede onde o dnsmasq responde | `192.168.0.0` |

Os demais (`USUARIO`, `SSH_PUBKEY_FILE`, versões e pastas) já vêm preenchidos. O `SSH_PUBKEY_FILE` aponta para `~/.ssh/cluster-key.pub` do usuário que roda o `sudo`: conferir que o arquivo existe (`ls ~/.ssh/cluster-key.pub`).
