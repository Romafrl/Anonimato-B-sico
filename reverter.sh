#!/bin/bash

# Script para reverter mudanças feitas pelo anonimato.sh
# Restaura MAC, IP, DNS, IPv6 e encerra VPN

if [[ $EUID -ne 0 ]]; then
  echo "Por favor, execute como root (sudo)."
  exit 1
fi

# Detectar interface ativa com IP
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | while read -r iface; do
  if ip addr show "$iface" | grep -q "state UP" && ip addr show "$iface" | grep -q "inet "; then
    echo "$iface"
    break
  fi
done)

if [ -z "$INTERFACE" ]; then
  echo "❌ Nenhuma interface ativa detectada."
  exit 1
fi

echo "🔧 Revertendo configurações na interface: $INTERFACE"

# Restaurar MAC original
echo "🔁 Restaurando MAC original..."
ip link set "$INTERFACE" down
macchanger -p "$INTERFACE"
ip link set "$INTERFACE" up

# Renovar IP
echo "🔁 Renovando IP..."
dhclient -r "$INTERFACE"
dhclient "$INTERFACE"

# Restaurar DNS
if [ -f /etc/resolv.conf.bak ]; then
  echo "🔁 Restaurando DNS original..."
  cp /etc/resolv.conf.bak /etc/resolv.conf
else
  echo "⚠️ Backup do DNS não encontrado. Usando DNS automático."
  rm -f /etc/resolv.conf
  systemctl restart systemd-resolved
fi

# Reativar IPv6
echo "🔁 Reativando IPv6..."
sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0

# Encerrar qualquer conexão VPN ativa via OpenVPN
echo "🔁 Encerrando conexões VPN (se houver)..."
for svc in $(systemctl list-units --type=service | grep openvpn@ | awk '{print $1}'); do
  systemctl stop "$svc"
  echo "🛑 VPN encerrada: $svc"
done

echo "✅ Tudo revertido. Seu sistema voltou ao estado padrão (tanto quanto possível)."
