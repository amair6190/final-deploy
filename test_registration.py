#!/usr/bin/env python
import os
import sys
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'it_ticketing_system.settings')
sys.path.append('/home/amair/Desktop/curser with github/final WO Whatsapp/backup-3')
django.setup()

from tickets.forms import CustomerRegistrationForm

def test_registration_form():
    print("=== TESTING REGISTRATION FORM ===")
    
    # Test 1: Empty form
    print("\n1. Testing empty form:")
    form = CustomerRegistrationForm()
    for field_name, field in form.fields.items():
        print(f"   {field_name}: required={field.required}, label='{field.label}'")
    
    # Test 2: Form with data WITHOUT email
    print("\n2. Testing form without email:")
    data = {
        'mobile': '9876543210',
        'first_name': 'Test',
        'last_name': 'User',
        'password1': 'TestPassword123!',
        'password2': 'TestPassword123!',
        # No email field
    }
    
    form = CustomerRegistrationForm(data=data)
    print(f"   Form is_valid: {form.is_valid()}")
    if not form.is_valid():
        print("   Form errors:")
        for field, errors in form.errors.items():
            print(f"     {field}: {errors}")
    
    # Test 3: Form with data WITH empty email
    print("\n3. Testing form with empty email:")
    data_with_empty_email = data.copy()
    data_with_empty_email['email'] = ''
    
    form = CustomerRegistrationForm(data=data_with_empty_email)
    print(f"   Form is_valid: {form.is_valid()}")
    if not form.is_valid():
        print("   Form errors:")
        for field, errors in form.errors.items():
            print(f"     {field}: {errors}")
    
    # Test 4: Check if username field is being created automatically
    print("\n4. Checking if 'username' field exists in form:")
    if 'username' in form.fields:
        username_field = form.fields['username']
        print(f"   Username field found: required={username_field.required}")
    else:
        print("   No username field in form")

if __name__ == "__main__":
    test_registration_form()
