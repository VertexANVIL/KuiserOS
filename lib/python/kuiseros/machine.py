import socket
import fabric
import icmplib
from typing import Mapping, Union, Any
from ipaddress import IPv4Address, IPv6Address

class Machine:
    """
    Represents a machine in the KuiserOS Operator framework
    """

    def __init__(self, id: str, config: Mapping[str, Any]):
        self.id = id
        self.config = config
        self.dns = config["dns"]

        self._ip: Union[IPv4Address, IPv6Address] = None
        self._conn: fabric.Connection = None

    @property
    def ip(self) -> Union[IPv4Address, IPv6Address]:
        if self._ip:
            return self._ip

        # try IPv6 first
        try:
            self._ip = IPv6Address(socket.getaddrinfo(
                host=self.dns,
                port=None,
                family=socket.AF_INET6,
                type=socket.SOCK_DGRAM
            )[0][4][0])

            return self._ip
        except OSError:
            pass

        # try IPv4
        try:
            self._ip = IPv4Address(socket.getaddrinfo(
                host=self.dns,
                port=None,
                family=socket.AF_INET,
                type=socket.SOCK_DGRAM
            )[0][4][0])

            return self._ip
        except OSError:
            pass

        # resolution failed :(
        return None

    @property
    def conn(self) -> fabric.Connection:
        """
        Returns a Fabric connection to connect to this machine, creating one if it does not exist
        """
        if not self._conn:
            self._conn = fabric.Connection(self.dns)
        return self._conn


class LivenessStat:
    def __init__(self, host: icmplib.Host = None):
        if host:
            self.alive = host.is_alive
            self.rtt = host.avg_rtt
        else:
            self.alive = None
            self.rtt = 0

    def __str__(self) -> str:
        if self.alive is None:
            return "Unknown"
        if self.alive is False:
            return "Down"
        return f"Up ({self.rtt}ms)"
