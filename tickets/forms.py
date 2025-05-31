from django import forms
from .models import Ticket, Message

class TicketCreationForm(forms.ModelForm):
    class Meta:
        model = Ticket
        fields = ['title', 'description', 'priority'] # Customer sets these initially
        # Customer and status are set programmatically

class MessageCreationForm(forms.ModelForm):
    class Meta:
        model = Message
        fields = ['content']
        widgets = {
            'content': forms.Textarea(attrs={'rows': 3, 'placeholder': 'Type your message...'}),
        }
        # Ticket and sender are set programmatically

class TicketUpdateForm(forms.ModelForm): # For agents
    class Meta:
        model = Ticket
        fields = ['status', 'priority'] # Agent might also re-assign later
