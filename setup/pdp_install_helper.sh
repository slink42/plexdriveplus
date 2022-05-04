[[ $USER = "root" ]] && \
curl -L  https://raw.githubusercontent.com/slink42/plexdriveplus/master/setup/plexdriveplus_install.sh -o plexdriveplus_install.sh && chmod +x ./plexdriveplus_install.sh && ./plexdriveplus_install.sh \
|| \
sudo curl -L  https://raw.githubusercontent.com/slink42/plexdriveplus/master/setup/plexdriveplus_install.sh -o plexdriveplus_install.sh && sudo chmod +x ./plexdriveplus_install.sh && sudo ./plexdriveplus_install.sh