export PACKAGING_ROOT STATE_ROOT PATH
export PKGNAME VERSION REL_VERSION BRANCH CHANNEL FULL_VERSION
export BASE_VERSION MAJOR_VERSION MINOR_VERSION
export KNO_VERSION KNO_MAJOR KNO_MINOR
export REPOMAN REPO_URL REPO_LOGIN REPO_CURLOPTS
export CODENAME DISTRO STATUS URGENCY

if [ "$(basename $0)" = "packaging.sh" ]; then
    echo "This file should be loaded (sourced) rather than run by itself";
    exit;
fi;

if [ -z "${PACKAGING_ROOT}" ]; then
    if [ -f packaging.sh ]; then
	PACKAGING_ROOT=$(pwd);
    else
	script_dir=$(dirname $0)
	if [ -f ${script_dir}/packaging.sh ]; then
	    PACKAGING_ROOT=$(pwd);
	fi;
    fi;
    if [ -z "${PACKAGING_ROOT}" ]; then
	echo "Couldn't find packaging root directory";
	exit;
    else
	fallback=${PACKAGING_ROOT}/fallback;
	PATH="${PATH}:${fallback}";
	STATE_ROOT=${PACKAGING_ROOT}/state;
    fi;
fi;

if [ $# -gt 0 ]  && [ -z "${NO_PKGNAME}" ]; then
    pkgname=$1;
    if [ "${pkgname%#*}" != "${pkgname}" ]; then
	branch=${pkgname#*#};
	pkgname=${pkgname%#*};
    fi;
    if [ ! -z "${PKGNAME}" ]; then
	if [ "${pkgname}" != "${PKGNAME}" ]; then
	    echo "Currently buildling '${PKGNAME}' not '$[pkgname}'";
	    exit 2;
	fi;
    elif [ ! -f sources/${pkgname} ]; then
	echo "No source information for '${pkgname}'";
	exit 2;
    elif [ ! -f ${STATE_ROOT}/PKGNAME ]; then
	echo "${pkgname}" > ${STATE_ROOT}/PKGNAME;
    elif [ "$(cat ${STATE_ROOT}/PKGNAME)" = "${pkgname}" ]; then
	:;
    else
	echo "Switching from $(cat ${STATE_ROOT}/PKGNAME) to ${pkgname}";
	rm ${STATE_ROOT}/*;
	echo "${pkgname}" > ${STATE_ROOT}/PKGNAME;
	if [ -n "${branch}" ]; then echo "${branch}" > ${STATE_ROOT}/BRANCH; fi;
	cp ${PACKAGING_ROOT}/defaults/* ${STATE_ROOT} 2> /dev/null;
	if [ -d ${PACKAGING_ROOT}/defaults/${pkgname} ]; then
	    cp ${PACKAGING_ROOT}/defaults/${pkgname}/* ${STATE_ROOT} 2> /dev/null;
	fi;
    fi;
    # Discard the package name (usually)
    if [ -z "${KEEP_PKG_ARG}" ]; then shift; fi;
fi;

if [ -f ${STATE_ROOT}/PKGNAME ]; then
    PKGNAME=$(cat ${STATE_ROOT}/PKGNAME);
fi;

if [ -f ${STATE_ROOT}/DISTRO ]; then
    DISTRO=$(cat ${STATE_ROOT}/DISTRO);
else
    DISTRO=$(lsb_release -s -c || echo release);
fi;

if [ -f ${STATE_ROOT}/CHANNEL ]; then
    CHANNEL=$(cat ${STATE_ROOT}/CHANNEL);
fi;

# These are used to probe for specific settings
PROBES=
push_probe() {
    local probe=$1
    if [ -n "${probe}" ] &&
	   [ "${probe}" = "${probe%.}" ] &&
	   [ "${probe}" = "${probe%..*}" ]; then
	if [ -z "${PROBES}" ]; then
	    PROBES="${probe}";
	else PROBES="${probe} ${PROBES}";
	fi;
    fi;
}
push_probe "${PKGNAME}";
push_probe "${PKGNAME}.${DISTRO}.${CHANNEL}";
push_probe "${PKGNAME}.${CHANNEL}";
push_probe "${PKGNAME}.${DISTRO}";

# This is all information which should come from getsource

if [ -f ${STATE_ROOT}/VERSION ]; then
    VERSION=$(cat ${STATE_ROOT}/VERSION);
fi;

if [ -f ${STATE_ROOT}/REL_VERSION ]; then
    REL_VERSION=$(cat ${STATE_ROOT}/REL_VERSION);
elif [ -f ${STATE_ROOT}/VERSION ]; then
    REL_VERSION=${VERSION%-*}
fi;

if [ -n "${branch}" ]; then
    BRANCH="${branch}";
    echo "${branch}" > ${STATE_ROOT}/BRANCH;
elif [ -f ${STATE_ROOT}/BRANCH ]; then
    BRANCH=$(cat ${STATE_ROOT}/BRANCH);
fi;

if [ -f ${STATE_ROOT}/FULL_VERSION ]; then
    FULL_VERSION=$(cat ${STATE_ROOT}/FULL_VERSION);
else
    FULL_VERSION=${VERSION};
fi;

if [ -f ${STATE_ROOT}/MAJOR_VERSION ]; then
    MAJOR_VERSION=$(cat ${STATE_ROOT}/MAJOR_VERSION);
else
    MAJOR_VERSION=$(echo $VERSION | cut -d'.' -f 1);
fi;

if [ -f ${STATE_ROOT}/MINOR_VERSION ]; then
    MINOR_VERSION=$(cat ${STATE_ROOT}/MINOR_VERSION || echo $version);
else
    MINOR_VERSION=$(echo $VERSION | cut -d'.' -f 2);
fi;

if [ -f ${STATE_ROOT}/BASE_VERSION ]; then
    BASE_VERSION=$(cat ${STATE_ROOT}/BASE_VERSION);
else
    BASE_VERSION=${VERSION}
fi;

# Information about KNO

if which knoconfig 2>/dev/null 1>/dev/null; then
    KNO_VERSION=$(knoconfig version);
    KNO_MAJOR=$(knoconfig major);
    KNO_MINOR=$(knoconfig minor);
fi;

# Other packaging parameters

if [ -f ${STATE_ROOT}/STATUS ]; then
    STATUS=$(cat ${STATE_ROOT}/STATUS);
else
    STATUS=stable;
fi;
if [ -f ${STATE_ROOT}/URGENCY ]; then
    URGENCY=$(cat ${STATE_ROOT}/URGENCY);
else
    URGENCY=normal
fi;

if [ -f ${STATE_ROOT}/GPGID ]; then
    GPGID=$(cat ${STATE_ROOT}/GPGID);
fi;

# Codenames (at least for Debian)

CODENAME=${DISTRO};
if [ -n "${CHANNEL}" ]; then CODENAME=${CODENAME}-${CHANNEL}; fi;

# Getting information about repos

if [ -n "${PKGTOOL}" ]; then
    :;
elif [ -f "${STATE_ROOT}/PKGTOOL" ]; then
    PKGTOOL=$(cat "${STATE_ROOT}/PKGTOOL");
else
    for probe in "${PACKAGING_ROOT}/defaults/${PKGNAME}/PKGTOOL" "${PACKAGING_ROOT}/defaults/PKGTOOL"; do
	if [ -z "${PKGTOOL}" ] && [ -f "${probe}" ]; then
	    PKGTOOL=$(cat "${probe}");
	fi;
    done;
    if [ -z "${PKGTOOL}" ] && which lsb_release 1>/dev/null 2>/dev/null; then
	release_type="$(lsb_release -s -i)";
	case ${release_type} in
	    Ubuntu|Debian)
		PKGTOOL=debtool;
		;;
	    RHEL|CENTOS)
		PKGTOOL=rpmtool;
		;;
	    *)
		PKGTOOL=
		;;
	esac
	if [ -n "${PKGTOOL}" ]; then
	    echo ${PKGTOOL} > ${STATE_ROOT}/PKGTOOL;
	fi;
    fi;
fi;

if [ -f "${STATE_ROOT}/REPOMAN" ]; then
    REPOMAN=$(cat "${STATE_ROOT}/REPOMAN");
elif [ -f "defaults/${PKGNAME}/REPOMAN" ]; then
    REPOMAN=$(cat "defaults/${PKGNAME}/REPOMAN");
elif [ -f "defaults/REPOMAN" ]; then
    REPOMAN=$(cat "defaults/REPOMAN");
else
    REPOMAN="Repository Manager <repoman@beingmeta.com>"
fi;

if [ -n "${REPO_URL}" ]; then
    # If we already have an URL in the environment assume everything
    # else has been set appropriately
    :
elif [ -f ${STATE_ROOT}/REPO_URL ]; then
    REPO_URL=$(cat ${STATE_ROOT}/REPO_URL);
    REPO_LOGIN=$(cat ${STATE_ROOT}/REPO_LOGIN 2>/dev/null || \
		     cat repos/default-login 2>/dev/null || \
		     echo);
    REPO_CURLOPTS=$(cat ${STATE_ROOT}/REPO_CURLOPTS 2>/dev/null || \
			cat repos/default-curlopts 2>/dev/null || \
			echo);
else
    for probe in ${PROBES}; do
	if [ -z "${REPO_URL}" ] && [ -f repos/${probe} ]; then
	    REPO_URL=$(cat repos/${probe});
	    if [ -f repos/${probe}-login ]; then
		REPO_LOGIN=$(cat repos/${probe}-login ); fi;
	    if [ -f repos/${probe}-curl ]; then
		REPO_CURL_OPTS=$(cat repos/${probe}-curlopts); fi;
	fi;
    done;
fi;
		   
if [ -z "${REPO_URL}" ] && [ -f repos/default ]; then
    REPO_URL=$(cat repos/default);
    REPO_LOGIN=$(cat ${STATE_ROOT}/REPO_LOGIN 2>/dev/null || cat repos/default-login 2>/dev/null || echo)
    REPO_CURL_OPTS=$(cat ${STATE_ROOT}/REPO_CURLOPTS 2>/dev/null || cat repos/default-curlopts 2>/dev/null || echo)
fi;

if [ -n "${DISTRO}" ]; then
    REPO_URL=$(echo ${REPO_URL} | sed - -e "s/@DISTRO@/-${DISTRO}/");
else
    REPO_URL=$(echo ${REPO_URL} | sed - -e "s/@CHANNEL@//");
fi;

if [ -n "${CHANNEL}" ]; then
    REPO_URL=$(echo ${REPO_URL} | sed - -e "s/@CHANNEL@/-${CHANNEL}/");
else
    REPO_URL=$(echo ${REPO_URL} | sed - -e "s/@CHANNEL@//");
fi;

if [ -f ${STATE_ROOT}/OUTDIR ]; then OUTDIR=$(cat ${STATE_ROOT}/OUTDIR); fi;

if [ -f ${STATE_ROOT}/GIT_NO_LFS ]; then GIT_NO_LFS=sorry; fi;

logmsg () {
    echo "pkg: $1" >&2;
}
