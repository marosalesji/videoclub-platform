#!/bin/bash

CONTROLLER_IP=${CONTROLLER_IP:-$(cd provision/cluster && terraform output -raw controller_public_ip)}
API_URL="http://$CONTROLLER_IP:30080"

MOVIE_ID_1=${MOVIE_ID_1:-3114}  # Toy Story 2
MOVIE_ID_2=${MOVIE_ID_2:-6934}  # Matrix Revolutions
MOVIE_ID_3=${MOVIE_ID_3:-71033} # El secreto de sus ojos

TOTAL=100

echo "=== Demo: saturación TURBO del sistema ==="
echo "Enviando $TOTAL ratings en paralelo a Toy Story 2, Matrix Revolutions y El secreto de sus ojos..."
echo ""

for i in $(seq 1 $TOTAL); do
  case $(( (i - 1) % 3 )) in
    0) MOVIE_ID=$MOVIE_ID_1 ;;
    1) MOVIE_ID=$MOVIE_ID_2 ;;
    2) MOVIE_ID=$MOVIE_ID_3 ;;
  esac

  USER_ID=$(( (i - 1) % 5 + 1 ))
  RATING=$(( (i % 5) + 1 ))

  curl -s -X POST $API_URL/rating \
    -H "Content-Type: application/json" \
    -d "{\"movie_id\": $MOVIE_ID, \"user_id\": $USER_ID, \"rating\": $RATING}" \
    -o /dev/null &

done

wait
echo ""
echo "=== $TOTAL ratings enviados en paralelo. Ve a CloudWatch y observa la queue. ==="
echo "Cuando estés listo para escalar el worker:"
echo "  kubectl scale deployment rating-worker --replicas=5"
