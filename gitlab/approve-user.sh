#!/bin/bash

# Usage: ./approve_user.sh <username>

USERNAME=$1
NAMESPACE="ml-build"

if [ -z "$USERNAME" ]; then
    echo "Usage: ./approve_user.sh <username>"
    exit 1
fi

echo "Searching for Toolbox pod..."
TOOLBOX_POD=$(kubectl get pods -l app=toolbox -n $NAMESPACE -o name | head -n 1)

if [ -z "$TOOLBOX_POD" ]; then
    echo "Error: Toolbox pod not found in namespace $NAMESPACE"
    exit 1
fi

echo "Approving and confirming user: $USERNAME"

kubectl exec -i $TOOLBOX_POD -n $NAMESPACE -- gitlab-rails console <<EOF
user = User.find_by_username('$USERNAME')
if user
  user.confirm
  user.unlock_access! if user.access_locked?
  user.activate if user.state == 'ldap_blocked' || user.state == 'blocked'
  
  if user.respond_to?(:approve!)
    user.approve! 
    puts "User $USERNAME has been approved."
  end
  
  if user.save
    puts "User $USERNAME successfully verified and activated."
  else
    puts "Failed to save user: " + user.errors.full_messages.join(", ")
  end
else
  puts "Error: User '$USERNAME' not found."
end
exit
EOF