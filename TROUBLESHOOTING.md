This documentation is for troubleshooting issues when using the devcontainer and
tools used in this repository, while developing the connector.

ToC:

- [airbyte-ci does not work](#airbyte-ci-does-not-work)
- [Unable to kind create cluster](#unable-to-kind-create-cluster)

## airbyte-ci does not work

- `airbyte-ci` is unable to run dagger
  - `docker logs <dagger engine>` says this:
    ```
    dnsmasq: failed to create inotify: No file descriptors available
    dnsmasq exited: exit status 5
    ```
      - This is due to that low `fs.inotify.max_user_instances` (like 128) on host.
      - Run `sudo sysctl fs.inotify.max_user_instances=8192` to fix.

This is the logs from dagger engine v0.13.3:

```
# expect more open files due to per-client SQLite databases
# many systems default to 1024 which is far too low
ulimit -n 1048576 || echo "cannot increase open FDs with ulimit, ignoring"

exec /usr/local/bin/dagger-engine --config /etc/dagger/engine.toml "$@"
time="2025-05-22T10:18:38Z" level=info msg="detected mtu 1500 via interface eth0"

dnsmasq: failed to create inotify: No file descriptors available
time="2025-05-22T10:18:38Z" level=debug msg="engine name: d35bb0a90fd9"
time="2025-05-22T10:18:38Z" level=debug msg="creating engine GRPC server"
dnsmasq exited: exit status 5
time="2025-05-22T10:18:38Z" level=debug msg="creating engine lockfile"
time="2025-05-22T10:18:38Z" level=debug msg="creating engine server"
time="2025-05-22T10:18:38Z" level=info msg="auto snapshotter: using overlayfs"
time="2025-05-22T10:18:38Z" level=warning msg="failed to release network namespace \"zcj6ufn9i2n38gu7m6nfpm550\" left over from previous run: plugin type=\"loopback\" failed (delete): unknown FS magic on \"/var/lib/dagger/net/cni/zcj6ufn9i2n38gu7m6nfpm550\": ef53"
buildkitd: failed to create engine: failed to create network providers: CNI setup error: plugin type="dnsname" failed (add): open /var/run/containers/cni/dnsname/dagger/pidfile: no such file or directory
```

As you can see in `dnsmasq: failed to create inotify: No file descriptors available`, this IS due to the insufficient `fs.inotify.max_user_instances` on host.

### Unable to kind create cluster

In case it's due to `could not find a log lilne that matches ...`:

```
$ kind create cluster --name devc1
Creating cluster "devc1" ...
 ✓ Ensuring node image (kindest/node:v1.33.1) 🖼 
 ✗ Preparing nodes 📦  
Deleted nodes: ["devc1-control-plane"]
ERROR: failed to create cluster: could not find a log line that matches "Reached target .*Multi-User System.*|detected cgroup v1"
```

See https://github.com/kubernetes-sigs/kind/issues/3423#issuecomment-1872074526.

In case it's due to `failed to remove control plane taint`:

```
$ kind create cluster --name devc1
Creating cluster "devc1" ...
 ✓ Ensuring node image (kindest/node:v1.33.1) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✗ Starting control-plane 🕹️ 
Deleted nodes: ["devc1-control-plane"]
ERROR: failed to create cluster: failed to remove control plane taint: command "docker exec --privileged devc1-control-plane kubectl --kubeconfig=/etc/kubernetes/admin.conf taint nodes --all node-role.kubernetes.io/control-plane-" failed with error: exit status 1
Command Output: E0521 02:42:53.441214     294 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://devc1-control-plane:6443/api?timeout=32s\": dial tcp 172.19.0.4:6443: connect: connection refused"
E0521 02:42:53.442574     294 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://devc1-control-plane:6443/api?timeout=32s\": dial tcp 172.19.0.4:6443: connect: connection refused"
The connection to the server devc1-control-plane:6443 was refused - did you specify the right host or port?
```

Probably you'd better use `docker-in-docker` instead of `docker-outside-of-docker`.

See https://github.com/kubernetes-sigs/kind/issues/2867#issuecomment-2868626460.
