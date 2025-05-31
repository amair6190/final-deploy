from django.urls import path
from . import views

urlpatterns = [
    path('register/', views.register_customer, name='register_customer'),
    path('dashboard/', views.customer_dashboard, name='customer_dashboard'),
    path('agent/dashboard/', views.agent_dashboard, name='agent_dashboard'),
    path('create/', views.create_ticket, name='create_ticket'),
    path('<int:ticket_id>/', views.ticket_detail, name='ticket_detail'),
    path('<int:ticket_id>/assign/', views.assign_ticket_to_self, name='assign_ticket_to_self'),
    path('<int:ticket_id>/update/', views.update_ticket_by_agent, name='update_ticket_by_agent'),
]
