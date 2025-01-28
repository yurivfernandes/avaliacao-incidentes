from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from ...models import Premissas
from ..serializers import PremissaSerializer


class PremissasView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user

        if user.is_tecnico:
            return Response(
                {"detail": "Acesso negado."}, status=status.HTTP_403_FORBIDDEN
            )

        if user.is_staff:
            premissas = Premissas.objects.all()
        elif user.is_gestor:
            premissas = Premissas.objects.filter(
                assignment__in=user.assignment_groups.all()
            )
        else:
            return Response(
                {"detail": "Acesso negado."}, status=status.HTTP_403_FORBIDDEN
            )

        serializer = PremissaSerializer(premissas, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def patch(self, request, *args, **kwargs):
        user = request.user

        try:
            premissa_id = kwargs.get("pk")
            premissa = Premissas.objects.get(id=premissa_id)
        except Premissas.DoesNotExist:
            return Response(
                {"detail": "Premissa não encontrada."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not user.is_staff and not (
            user.is_gestor
            and premissa.assignment in user.assignment_groups.all()
        ):
            return Response(
                {"detail": "Acesso negado."}, status=status.HTTP_403_FORBIDDEN
            )

        serializer = PremissaSerializer(
            premissa, data=request.data, partial=True
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def post(self, request, *args, **kwargs):
        user = request.user

        if not user.is_staff:
            assignment_id = request.data.get("assignment")
            if (
                not assignment_id
                or not user.assignment_groups.filter(id=assignment_id).exists()
            ):
                return Response(
                    {"detail": "Acesso negado."},
                    status=status.HTTP_403_FORBIDDEN,
                )

        serializer = PremissaSerializer(data=request.data)
        if serializer.is_valid():
            try:
                serializer.save()
                return Response(
                    serializer.data, status=status.HTTP_201_CREATED
                )
            except ValidationError as e:
                return Response(
                    {"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
