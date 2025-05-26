#/bin/bash
echo "Option1"
ENC_KEY1=$(openssl rand -base64 32)
echo "Encryption key is: ${ENC_KEY1}"

echo "Option2"
ENC_KEY2=$(head -c 32 /dev/urandom | base64)
echo "Encryption key is: ${ENC_KEY2}"
