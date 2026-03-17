#!/bin/bash
set -e

CONTROLLER_IP=${CONTROLLER_IP:-$(cd provision/cluster && terraform output -raw controller_public_ip)}
API_URL="http://$CONTROLLER_IP:30080"

echo "=== Demo: flujo normal de ratings ==="
echo ""

echo "Enviando rating de 3 estrellas para movie_id=3114"
curl -s -X POST $API_URL/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 3114, "user_id": 1, "rating": 3, "review": "Estuvo bien, nada especial"}' | python3 -m json.tool
echo ""

sleep 2

echo "Enviando rating de 5 estrellas para movie_id=6934"
curl -s -X POST $API_URL/rating \
  -H "Content-Type: application/json" \
  -d '{"movie_id": 6934, "user_id": 2, "rating": 5, "review": "Una obra maestra, la recomiendo mucho"}' | python3 -m json.tool
echo ""

echo "=== Listo. Revisa los logs del API y del worker: ==="
echo "  kubectl logs -f deployment/rating-api"
echo "  kubectl logs -f deployment/rating-worker"
