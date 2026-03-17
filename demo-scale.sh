#!/bin/bash
set -e

CONTROLLER_IP=${CONTROLLER_IP:-$(cd provision/cluster && terraform output -raw controller_public_ip)}
API_URL="http://$CONTROLLER_IP:30080"

MOVIE_ID_1=${MOVIE_ID_1:-3114} # toy story 2
MOVIE_ID_2=${MOVIE_ID_2:-6934} # matrix revolutions
MOVIE_ID_3=${MOVIE_ID_3:-71033} # el secreto de sus ojos

TOTAL=100

echo "=== Demo: saturación del sistema ==="
echo "Enviando $TOTAL ratings a las películas $MOVIE_ID_1, $MOVIE_ID_2 y $MOVIE_ID_3..."
echo ""

for i in $(seq 1 $TOTAL); do
  # Rotar entre los 3 movie_ids
  case $(( (i - 1) % 3 )) in
    0) MOVIE_ID=$MOVIE_ID_1 ;;
    1) MOVIE_ID=$MOVIE_ID_2 ;;
    2) MOVIE_ID=$MOVIE_ID_3 ;;
  esac

  # Rotar entre los 5 usuarios
  USER_ID=$(( (i - 1) % 5 + 1 ))

  # Rating aleatorio entre 1 y 5
  RATING=$(( (i % 5) + 1 ))

  curl -s -X POST $API_URL/rating \
    -H "Content-Type: application/json" \
    -d "{\"movie_id\": $MOVIE_ID, \"user_id\": $USER_ID, \"rating\": $RATING}" \
    -o /dev/null

  echo "[$i/$TOTAL] movie_id=$MOVIE_ID user_id=$USER_ID rating=$RATING"
done

echo ""
echo "=== $TOTAL ratings enviados. Ve a CloudWatch y observa la queue. ==="
echo "Cuando estés listo para escalar el worker:"
echo "  kubectl scale deployment rating-worker --replicas=5"
