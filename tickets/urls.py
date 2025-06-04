# tickets/urls.py

from django.urls import path
from django.contrib.auth import views as auth_views # Import Django's auth views directly
from . import views # This imports your own views from tickets/views.py (like CustomLoginView, register_customer, etc.)

app_name = 'tickets'

urlpatterns = [
    # Authentication URLs
    path('login/', views.CustomLoginView.as_view(), name='login'), # Use your CustomLoginView from tickets.views

    path('logout/', auth_views.LogoutView.as_view(), name='logout'), # Use auth_views.LogoutView directly

    # Your existing app-specific URLs
    path('register/', views.register_customer, name='register_customer'),
    path('dashboard/', views.customer_dashboard, name='customer_dashboard'),
    path('agent/dashboard/', views.agent_dashboard, name='agent_dashboard'),
    path('create/', views.create_ticket, name='create_ticket'),
    path('<int:ticket_id>/', views.ticket_detail, name='ticket_detail'),
    path('<int:ticket_id>/assign/', views.assign_ticket_to_self, name='assign_ticket_to_self'),
    path('<int:ticket_id>/update/', views.update_ticket_by_agent, name='update_ticket_by_agent'),
]
