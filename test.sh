echo "Waiting for all 3 targets to become healthy..."
echo "This takes 5-7 minutes per instance..."
echo ""

TG_ARN=$(terraform output -raw target_group_arn)

# Check every 30 seconds
for i in {1..20}; do
  HEALTHY_COUNT=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --profile demo \
    --region us-east-1 \
    --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
    --output text)
  
  echo "Check $i/20: $HEALTHY_COUNT of 3 targets healthy"
  
  if [ "$HEALTHY_COUNT" = "3" ]; then
    echo "✅ All 3 targets are healthy!"
    break
  fi
  
  sleep 30
done

# Show detailed status
echo ""
echo "Final target health status:"
aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN" \
  --profile demo \
  --region us-east-1 \
  --output table
