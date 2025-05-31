from django.contrib import admin
from .models import Ticket, Message

class MessageInline(admin.TabularInline): # Or StackedInline for more space
    model = Message
    extra = 1 # Number of empty forms to display
    readonly_fields = ('sender', 'timestamp') # Prevent editing these in the inline

@admin.register(Ticket)
class TicketAdmin(admin.ModelAdmin):
    list_display = ('id', 'title', 'customer', 'agent', 'status', 'priority', 'created_at', 'updated_at')
    list_filter = ('status', 'priority', 'agent', 'created_at')
    search_fields = ('title', 'description', 'customer__username', 'agent__username')
    # To make assigning agents easier in admin:
    raw_id_fields = ('customer', 'agent')
    inlines = [MessageInline] # Add messages inline

@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ('ticket', 'sender', 'timestamp', 'content_excerpt')
    list_filter = ('sender', 'timestamp')
    search_fields = ('content', 'ticket__title', 'sender__username')
    raw_id_fields = ('ticket', 'sender')

    def content_excerpt(self, obj):
        return obj.content[:50] + '...' if len(obj.content) > 50 else obj.content
    content_excerpt.short_description = 'Content'
