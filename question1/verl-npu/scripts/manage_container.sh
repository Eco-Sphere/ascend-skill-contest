#!/bin/bash
# verl 容器管理脚本

case "$1" in
    start)
        echo "Starting verl-npu container..."
        docker start verl-npu
        ;;
    stop)
        echo "Stopping verl-npu container..."
        docker stop verl-npu
        ;;
    restart)
        echo "Restarting verl-npu container..."
        docker restart verl-npu
        ;;
    remove)
        echo "Removing verl-npu container..."
        docker stop verl-npu && docker rm verl-npu
        ;;
    status)
        docker ps -a | grep verl-npu
        ;;
    logs)
        docker logs -f verl-npu
        ;;
    exec)
        docker exec -it verl-npu bash
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|remove|status|logs|exec}"
        exit 1
        ;;
esac
