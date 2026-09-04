class VaultTemplate {
  final String title;
  final String content;
  final String category;
  final bool isPro;

  const VaultTemplate({
    required this.title,
    required this.content,
    required this.category,
    this.isPro = false,
  });
}

class TemplateVaultData {
  static const List<VaultTemplate> freeTemplates = [
    VaultTemplate(
      title: 'Git Conventional Commit',
      category: 'Dev',
      content: 'fix({input:scope}): {input:summary} - {date}',
      isPro: false,
    ),
    VaultTemplate(
      title: 'Quick Bug Reproduction',
      category: 'Dev',
      content: '**Steps to Reproduce:** 1. {input:step1} 2. {input:step2} **Expected:** {input:expected}',
      isPro: false,
    ),
    VaultTemplate(
      title: 'UTM Campaign Builder',
      category: 'Growth',
      content: 'https://{input:domain}/?utm_source={input:source}&utm_medium={input:medium}&utm_campaign={input:campaign}',
      isPro: false,
    ),
    VaultTemplate(
      title: 'Social Hook Post',
      category: 'Growth',
      content: '💡 The biggest mistake people make with {input:topic}:\n\nHere is how to fix it in 3 steps: 👇',
      isPro: false,
    ),
    VaultTemplate(
      title: 'Quick Client Follow-up',
      category: 'Sales',
      content: 'Hi {input:name}, checking in on our proposal sent on {date}. Do you have 5 mins tomorrow?',
      isPro: false,
    ),
    VaultTemplate(
      title: 'Invoice Dispatch Note',
      category: 'Sales',
      content: 'Invoice #{input:inv_no} for {input:project} is ready. Total: \${input:amount}. Due date: {input:due_date}.',
      isPro: false,
    ),
    VaultTemplate(
      title: 'Customer Ticket Resolution',
      category: 'Support',
      content: 'Hi {input:customer}, issue #{input:ticket_id} has been resolved. Let us know if you need further help!',
      isPro: false,
    ),
    VaultTemplate(
      title: 'Standard Meeting Agenda',
      category: 'Support',
      content: 'Meeting on {date} at {time}.\nAgenda:\n1. Status update\n2. Blockers: {input:blockers}',
      isPro: false,
    ),
    VaultTemplate(
      title: 'Student Assignment Feedback',
      category: 'Education',
      content: 'Great work on {input:topic}, {input:student}! Score: {input:score}/100. Feedback: {input:feedback}',
      isPro: false,
    ),
    VaultTemplate(
      title: 'Timestamped Clipboard Dump',
      category: 'Dev',
      content: 'Captured on {date} at {time}:\n{clipboard}',
      isPro: false,
    ),
  ];

  static final List<VaultTemplate> proTemplates = _generateProTemplates();

  static List<VaultTemplate> getAllTemplates() {
    return [...freeTemplates, ...proTemplates];
  }

  static List<VaultTemplate> _generateProTemplates() {
    final List<VaultTemplate> list = [];

    // Dev Templates (25+)
    final devItems = [
      ('PR Code Review Rubric', '🔍 **PR Review: {input:pr_title}**\n- [ ] Unit Tests Passed\n- [ ] Clean Architecture Check\n- [ ] Edge Cases Covered: {input:edge_cases}\n- [ ] Benchmark Impact: {input:perf_impact}', 'Dev'),
      ('Docker Compose Service Node', 'services:\n  {input:service_name}:\n    image: {input:image_name}:latest\n    ports:\n      - "{input:port}:{input:port}"\n    environment:\n      - NODE_ENV=production\n      - DB_URI={input:db_uri}', 'Dev'),
      ('SQL Migration Rollback Template', '-- Migration #{input:migration_id}: {input:description}\nBEGIN TRANSACTION;\nDROP TABLE IF EXISTS {input:table_name};\nALTER TABLE {input:ref_table} DROP COLUMN {input:col_name};\nCOMMIT;', 'Dev'),
      ('GraphQL Query Mutation Template', 'mutation {input:mutation_name}(\$id: ID!, \$input: {input:input_type}!) {\n  {input:field_name}(id: \$id, input: \$input) {\n    id\n    status\n    updatedAt\n  }\n}', 'Dev'),
      ('Kubernetes Deployment Spec', 'apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: {input:app_name}\n  labels:\n    app: {input:app_name}\nspec:\n  replicas: {input:replicas}\n  selector:\n    matchLabels:\n      app: {input:app_name}', 'Dev'),
      ('REST API Endpoint Contract', '### {input:method} /api/v1/{input:endpoint}\n**Headers:** `Authorization: Bearer {input:token_env}`\n**Request Body:**\n```json\n{\n  "id": "{input:id_field}",\n  "status": "{input:status_val}"\n}\n```\n**Response 200 OK**', 'Dev'),
      ('CI/CD Pipeline Failure Alert', '🚨 **Pipeline Build Failed: {input:repo_name}**\nBranch: `{input:branch}` | Commit: `{input:commit_sha}`\nFailed Step: `{input:failed_step}`\nLogs: {input:log_url}\nTriggered on {date} at {time}', 'Dev'),
      ('Feature Flag Config Spec', '{\n  "feature_key": "{input:feature_key}",\n  "enabled": {input:is_enabled},\n  "rollout_percentage": {input:percentage},\n  "target_groups": ["{input:target_group}"]\n}', 'Dev'),
      ('Sentry Incident Triage Template', '📌 **Sentry Error: {input:error_type}**\nEnvironment: `{input:env}` | Users Affected: {input:user_count}\nTrace: {input:stack_trace}\nAssigned Engineer: @{input:engineer}', 'Dev'),
      ('FastAPI Pydantic Schema', 'from pydantic import BaseModel, Field\n\nclass {input:model_name}Schema(BaseModel):\n    id: int\n    {input:field_1}: str = Field(..., description="{input:desc_1}")\n    created_at: str = "{date}"', 'Dev'),
    ];

    for (int i = 0; i < 3; i++) {
      for (var item in devItems) {
        list.add(VaultTemplate(
          title: i == 0 ? item.$1 : '${item.$1} (v${i + 1})',
          content: item.$2,
          category: item.$3,
          isPro: true,
        ));
      }
    }

    // Growth Templates (25+)
    final growthItems = [
      ('Product Hunt Launch Pitch', '🚀 We just launched **{input:product_name}** on Product Hunt!\n\n{input:tagline}\n\nKey Features:\n✨ {input:feat_1}\n⚡ {input:feat_2}\n\nCheck us out & support here: {input:ph_url}', 'Growth'),
      ('Newsletter Sponsorship Pitch', 'Hi {input:creator_name},\n\nLove the latest edition of {input:newsletter_name}!\nWe would love to sponsor an upcoming issue to introduce our tool, {input:tool_name}, to your audience of {input:subscriber_count} readers.\n\nAre you open for Q{input:quarter} placements?', 'Growth'),
      ('Meta Ads High-Hook Copy', 'Stop wasting time on {input:pain_point}!\n\nWith {input:product_name}, you get:\n✅ {input:benefit_1}\n✅ {input:benefit_2}\n\n👉 Try it risk-free today: {input:cta_url}', 'Growth'),
      ('SEO Pillar Content Outline', '<h1>The Ultimate Guide to {input:target_keyword} ({date})</h1>\n<h2>1. What is {input:target_keyword}?</h2>\n<h2>2. Top 5 Best Practices for {input:use_case}</h2>\n<h2>3. Common Mistakes to Avoid</h2>', 'Growth'),
      ('Cold Twitter/X DM Outreach', 'Hey {input:name}! Noticed your tweet about {input:topic}.\nWe built a quick tool that automates {input:solution_summary}.\nWould love to get your feedback if you have 2 mins! {input:demo_link}', 'Growth'),
    ];

    for (int i = 0; i < 5; i++) {
      for (var item in growthItems) {
        list.add(VaultTemplate(
          title: i == 0 ? item.$1 : '${item.$1} (Variant ${i + 1})',
          content: item.$2,
          category: item.$3,
          isPro: true,
        ));
      }
    }

    // Sales Templates (25+)
    final salesItems = [
      ('Founder Cold Email Pitch', 'Hi {input:prospect_name},\n\nI noticed {input:company_name} is growing your {input:department} team.\nWe helped {input:competitor_name} increase {input:metric} by {input:percentage}% in 30 days.\n\nWorth a 10-min chat this Thursday?', 'Sales'),
      ('Agency Retainer Proposal', '📋 **Retainer Proposal for {input:client_company}**\nScope of Work:\n- {input:deliverable_1}\n- {input:deliverable_2}\n\nMonthly Fee: \${input:monthly_fee}\nStart Date: {date}\nTerms: Net 15', 'Sales'),
      ('Contract Renewal Reminder', 'Hi {input:client_name},\n\nOur service agreement for {input:service_name} expires on {input:expiry_date}.\nWe would love to extend for another year with our loyalty discount of {input:discount}%.\n\nLet me know if you would like me to send the updated Docusign!', 'Sales'),
      ('Price Increase Notification', 'Dear {input:client_name},\n\nTo continue delivering top-tier {input:service_type}, our standard rate will adjust to \${input:new_rate} effective {input:effective_date}.\nAs a legacy client, your rate is locked until {input:lock_date}.', 'Sales'),
      ('Objection Handling: Budget', 'I completely understand {input:prospect_name}, budget is top of mind.\nThat\'s why we offer a flexible {input:tier_name} plan at \${input:tier_price}/mo that delivers immediate ROI on {input:key_outcome}.', 'Sales'),
    ];

    for (int i = 0; i < 5; i++) {
      for (var item in salesItems) {
        list.add(VaultTemplate(
          title: i == 0 ? item.$1 : '${item.$1} (Option ${i + 1})',
          content: item.$2,
          category: item.$3,
          isPro: true,
        ));
      }
    }

    // Support Templates (25+)
    final supportItems = [
      ('P1 Critical Incident Update', '🚨 **CRITICAL INCIDENT UPDATE #{input:inc_num}**\nSystem: `{input:affected_system}`\nStatus: {input:current_status}\nETA for Fix: {input:eta}\nNext Update: {time}', 'Support'),
      ('Refund Authorization Note', 'Hello {input:customer_name},\n\nWe have processed your refund of \${input:amount} for transaction #{input:txn_id}.\nPlease allow 3-5 business days for it to reflect on your statement.', 'Support'),
      ('Feature Backlog Acknowledgement', 'Hi {input:user_name},\n\nThank you for suggesting {input:feature_title}!\nI have logged this in our product queue under ID #{input:feature_id}. We will notify you when it enters beta testing.', 'Support'),
      ('VIP Customer Onboarding Note', 'Welcome aboard, {input:vip_name}!\nYour dedicated account manager is @{input:account_mgr}.\nYour private Slack connect channel: {input:slack_link}', 'Support'),
      ('SLA Breach Warning Response', 'Warning: SLA threshold of {input:sla_hours} hours reached for Ticket #{input:ticket_id}.\nCustomer: {input:customer_org}\nAssigned Rep: {input:rep_name}', 'Support'),
    ];

    for (int i = 0; i < 5; i++) {
      for (var item in supportItems) {
        list.add(VaultTemplate(
          title: i == 0 ? item.$1 : '${item.$1} (Format ${i + 1})',
          content: item.$2,
          category: item.$3,
          isPro: true,
        ));
      }
    }

    // Founder Templates (25+)
    final founderItems = [
      ('Daily EOD Standup Report', '🚀 **Founder Daily EOD - {date}**\n\n**Wins:**\n- {input:win_1}\n**Blockers:**\n- {input:blocker_1}\n**Top 3 Tomorrow:**\n1. {input:priority_1}', 'Founder'),
      ('Monthly Investor Update Letter', '📈 **{input:company_name} - Monthly Update ({date})**\n\n**MRR:** \${input:mrr} (+{input:mrr_growth}% MoM)\n**Runway:** {input:runway_months} months\n**Highlights:**\n- {input:highlight_1}\n**Asks:** {input:investor_ask}', 'Founder'),
      ('One-on-One Meeting Framework', '🤝 **1-on-1 with @{input:team_member}**\nDate: {date}\n1. What went well this week?\n2. Roadblocks: {input:roadblock}\n3. Action Items: {input:action_item}', 'Founder'),
      ('Executive Advisory Invite', 'Dear {input:advisor_name},\n\nFollowing your experience with {input:domain_expertise}, I would love to invite you to join {input:company_name}\'s advisory board.\nWe are offering {input:equity_pct}% advisory equity.', 'Founder'),
      ('All-Hands Meeting Broadcast', 'Team, our quarterly All-Hands is scheduled for {date} at {time}.\nTheme: {input:theme}\nQ&A Submissions: {input:slido_url}', 'Founder'),
    ];

    for (int i = 0; i < 5; i++) {
      for (var item in founderItems) {
        list.add(VaultTemplate(
          title: i == 0 ? item.$1 : '${item.$1} (Draft ${i + 1})',
          content: item.$2,
          category: item.$3,
          isPro: true,
        ));
      }
    }

    // Education Templates (25+)
    final eduItems = [
      ('Lecture Outline Template', '📚 **Lecture: {input:lecture_title}**\nDate: {date}\nTarget Audience: {input:grade_level}\nKey Concepts:\n1. {input:concept_1}\n2. {input:concept_2}', 'Education'),
      ('Lab Exercise Instructions', '🧪 **Lab #{input:lab_no}: {input:lab_name}**\nObjective: {input:objective}\nRequired Tools: {input:tools}\nSubmission Deadline: {date} at {time}', 'Education'),
      ('Hackathon Judging Scorecard', '🏆 **Hackathon Scorecard: {input:team_name}**\n- Innovation (1-10): {input:score_innov}\n- Tech Execution (1-10): {input:score_exec}\n- Presentation (1-10): {input:score_pres}\nTotal: {input:total_score}/30', 'Education'),
      ('Parent-Teacher Communication', 'Dear {input:parent_name},\n\nThis is a quick update regarding {input:student_name}\'s progress in {input:subject}.\nKey Strength: {input:strength}\nFocus Area: {input:focus_area}', 'Education'),
      ('Online Course Module Summary', '🎓 **Module #{input:mod_no}: {input:mod_title}**\nDuration: {input:duration_mins} mins\nTakeaway Quiz: {input:quiz_url}', 'Education'),
    ];

    for (int i = 0; i < 5; i++) {
      for (var item in eduItems) {
        list.add(VaultTemplate(
          title: i == 0 ? item.$1 : '${item.$1} (Preset ${i + 1})',
          content: item.$2,
          category: item.$3,
          isPro: true,
        ));
      }
    }

    return list; // Total ~150+ pro templates
  }
}
