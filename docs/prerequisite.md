
# Prerequisities

## Enviroment For Performance Test
We evaluate Orthrus throughly on Ubuntu 20.04. If you also use this release, you can simply run **init.sh under the root directory** to setup environment.

If you are using a similiar OS release, you can refer to commands in init.sh. Else, you can download related packages yourself.

Not that you should use cmake version >= 3.20. In our init.sh, we install cmake 3.29.

```shell
sudo ./init.sh
```

## Environment for Fault Injection Evaluation

run table2_env.sh.

It will build and install our modified Clang compiler with fault injection features, and configure an automatic testing platform written in python.
