from django.contrib import admin
from django.urls import path
from .views import ok

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', ok),
]
