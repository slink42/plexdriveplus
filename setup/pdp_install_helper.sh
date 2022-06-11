# set branch to download a specific branch, otherwise current master branch will be used

# check if PDP_BRANCH is specified in env file
INSTALL_ENV_FILE=install.env
[[ -z "$1" ]] || INSTALL_ENV_FILE=$1
[[ -f $INSTALL_ENV_FILE ]] && source $INSTALL_ENV_FILE || echo "warning $INSTALL_ENV_FILE file not found"

[ -z "$PDP_BRANCH" ] && PDP_BRANCH=master
([[ $USER = "root" ]] && SUDO="" || SUDO="sudo") && \
$SUDO curl  -H 'Cache-Control: no-cache, no-store' -L  https://raw.githubusercontent.com/slink42/plexdriveplus/$PDP_BRANCH/setup/plexdriveplus_install.sh -o plexdriveplus_install.sh && $SUDO chmod +x ./plexdriveplus_install.sh && $SUDO ./plexdriveplus_install.sh