#!/usr/bin/bash

set \
	-e \
	#

declare \
	-i \
	-- \
	exit_code=0 \
	#

function show_usage
{
	echo "usage: $0 <up|down> NAMESPACE" >&2
}

if [[ $@ == help ]]
then
	show_usage
elif [[ $# -eq 2 ]]
then
	declare \
		-r \
		-- \
		subcommand="$1" \
		namespace="$2" \
		#

	case "${subcommand}" in
		down)
			# Delete the network namespace
			ip \
				netns del \
				"${namespace}" \
				#
			echo "info: network namespace '${namespace}' deleted" >&2
			# The Wireguard interface within the namespace is deleted automatically,
			# so it isn't necessary to run `ip -netns ${namespace} link delete dev wg0`
			;;
		up)
			# Create the network namespace
			ip \
				netns add \
				"${namespace}" \
				#
			echo "info: network namespace '${namespace}' created" >&2

			# Network devices within the same network namespace must have unique names.
			# Since the Wireguard interface is created in a shared namespace at first,
			# steps must be taken to reduce the risk of a name collision.
			# For `$SRANDOM` see the Bash manual:
			# https://www.gnu.org/software/bash/manual/bash#index-SRANDOM
			interface="wgnetns-$(( SRANDOM % 999999 ))"
			# The Wireguard interface is renamed to `wg0` later, once it has been moved
			# into its own namespace

			# Create the Wireguard interface in the current network namespace
			ip \
				link add \
				dev "${interface}" \
				type wireguard \
				#
			echo "info: Wireguard interface created under temporary name '${interface}'" >&2

			# Move the Wireguard interface into the new network namespace
			ip \
				link set \
				dev "${interface}" \
				netns "${namespace}" \
				#
			echo "debug: Wireguard interface '${interface}' moved into network namespace '${namespace}'" >&2

			# Network devices in different network namespaces can have the same name.
			# Take advantage of this to provide the Wireguard interface with a more
			# reasonable name.
			ip \
				-netns "${namespace}" \
				link set \
				dev "${interface}" \
				name wg0 \
				#
			echo "debug: Wireguard interface renamed to 'wg0' inside network namespace '${namespace}'" >&2
			;;
		*)
			show_usage
			exit_code=1
			;;
	esac
else
	show_usage
	exit_code=1
fi

exit "${exit_code}"