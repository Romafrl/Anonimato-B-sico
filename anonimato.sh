#!/bin/bash

# Script Anonimato Básico para Linux (Debian/Kali/etc)
# Precisa ser rodado como root (sudo)

# Verifica root
if [[ $EUID -ne 0 ]]; then
  echo "Por favor, rode o script como root (sudo)."
  exit 1
fi

# Função para instalar pacotes caso não estejam presentes
instalar_pacote() {
  if ! command -v "$1" &> /dev/null; then
    echo "Pacote '$1' não encontrado. Instalando..."
    apt update && apt install -y "$1"
    if [ $? -ne 0 ]; then
      echo "Erro ao instalar pacote $1. Abortando."
      exit 1
    fi
  fi
}

# Instala pacotes essenciais
instalar_pacote whiptail
instalar_pacote macchanger
instalar_pacote openvpn

# Detecta interface ativa (UP e com IP)
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | while read -r iface; do
  if ip addr show "$iface" | grep -q "state UP" && ip addr show "$iface" | grep -q "inet "; then
    echo "$iface"
    break
  fi
done)

if [ -z "$INTERFACE" ]; then
  whiptail --msgbox "Não foi possível detectar interface ativa com IP." 8 40
  exit 1
fi

# Restante do script (mesmo que antes)

mudar_mac() {
  whiptail --yesno "Deseja mudar o MAC da interface $INTERFACE?" 8 50
  if [ $? -eq 0 ]; then
    ip link set "$INTERFACE" down
    macchanger -r "$INTERFACE" | tee /tmp/macchanger.log
    ip link set "$INTERFACE" up
    whiptail --msgbox "MAC alterado. Veja detalhes em /tmp/macchanger.log" 8 50
  fi
}

renovar_ip() {
  whiptail --yesno "Deseja renovar o IP da interface $INTERFACE via DHCP?" 8 50
  if [ $? -eq 0 ]; then
    dhclient -r "$INTERFACE"
    dhclient "$INTERFACE"
    whiptail --msgbox "IP renovado." 6 30
  fi
}

configurar_dns() {
  whiptail --yesno "Deseja configurar DNS para 1.1.1.1 (Cloudflare)?" 8 50
  if [ $? -eq 0 ]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    whiptail --msgbox "DNS configurado para 1.1.1.1" 6 35
  fi
}

desativar_ipv6() {
  whiptail --yesno "Deseja desativar IPv6 temporariamente?" 8 40
  if [ $? -eq 0 ]; then
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1
    whiptail --msgbox "IPv6 desativado temporariamente." 6 40
  fi
}

limpar_caches_logs() {
  whiptail --yesno "Deseja limpar caches DNS e alguns logs básicos?" 8 50
  if [ $? -eq 0 ]; then
    if command -v systemd-resolve &> /dev/null; then
      systemd-resolve --flush-caches
    fi

    if systemctl is-active --quiet nscd; then
      systemctl restart nscd
    fi

    rm -rf ~/.cache/*

    whiptail --msgbox "Caches e alguns logs limpos." 6 35
  fi
}

iniciar_vpn() {
  whiptail --yesno "Deseja iniciar VPN (OpenVPN)? Você deve ter uma config pronta." 8 60
  if [ $? -eq 0 ]; then
    whiptail --inputbox "Digite o nome da config OpenVPN (ex: myvpn.conf):" 8 60 2> /tmp/vpnconfig.txt
    CONFIG=$(cat /tmp/vpnconfig.txt)
    if [ -f "/etc/openvpn/$CONFIG" ]; then
      systemctl start "openvpn@$CONFIG"
      whiptail --msgbox "VPN iniciada com a config $CONFIG." 6 40
    else
      whiptail --msgbox "Configuração $CONFIG não encontrada em /etc/openvpn/." 8 50
    fi
  fi
}

instrucoes_user_agent() {
  whiptail --msgbox "Para mudar User-Agent no navegador, use extensões como 'User-Agent Switcher' no Chrome ou Firefox.\n\nNão é possível alterar via script bash." 10 60
}

# Execução das funções

mudar_mac
renovar_ip
configurar_dns
desativar_ipv6
limpar_caches_logs
iniciar_vpn
instrucoes_user_agent

whiptail --msgbox "Processo finalizado! Seu anonimato básico foi configurado." 8 50
