#!/usr/bin/env python
# coding: utf-8

# In[1]:


import pandas as pd

events = pd.read_csv(r'C:\Ongoing course\Projects\google_analytics\dataset.csv')
sessions = pd.read_csv(r'C:\Ongoing course\Projects\google_analytics\sessions.csv')   # we won't use this
items = pd.read_csv(r'C:\Ongoing course\Projects\google_analytics\items.csv')


# In[5]:


# sessions.csv is 100% null, so we extract source from the events that DO have it
# begin_checkout has 89% coverage, purchase has 91.5%

channel_map = (
    events[events['source'].notna()]
    .sort_values('event_name')           # prioritises purchase > begin_checkout
    .groupby('session_id')[['source', 'medium', 'campaign']]
    .first()
    .reset_index()
    .rename(columns={'source':'session_source', 'medium':'session_medium', 'campaign':'session_campaign'})
)

print(f"Sessions with channel data: {len(channel_map)} / {events['session_id'].nunique()}")


# In[6]:


# Drop the broken original source/medium columns
events = events.drop(columns=['source', 'medium', 'campaign'])

# Merge the clean session-level channel data
master = events.merge(channel_map, on='session_id', how='left')

# Fill unknowns
master['session_source'] = master['session_source'].fillna('unknown')
master['session_medium'] = master['session_medium'].fillna('unknown')

print(master['session_source'].value_counts())


# In[8]:


# ── Channel Grouping ──────────────────────────────────────────
def assign_channel(source, medium):
    if source == 'unknown':
        return 'Unknown'
    if source == 'shop.googlemerchandisestore.com':
        return 'Self-Referral'
    if source == 'google' and medium == 'cpc':
        return 'Google Paid'
    if source == 'google' and medium == 'organic':
        return 'Google Organic'
    if source == '(direct)' or medium == '(none)':
        return 'Direct'
    if medium == 'referral':
        return 'Referral'
    if source in ['<Other>', '(data deleted)'] or medium in ['<Other>', '(data deleted)']:
        return 'Obfuscated'
    return 'Other'

master['channel'] = master.apply(
    lambda r: assign_channel(r['session_source'], r['session_medium']), axis=1
)

# ── Final save ────────────────────────────────────────────────
master['event_date'] = pd.to_datetime(master['event_date'], format='%Y%m%d')
master.to_csv('master_events.csv', index=False)

# ── Verify ────────────────────────────────────────────────────
print(master['channel'].value_counts())
print('\nPurchases by channel:')
print(master[master['event_name']=='purchase']['channel'].value_counts())


# In[10]:


# Fix date format
master['event_date'] = pd.to_datetime(master['event_date'], format='%Y%m%d')

# Save master file
master.to_csv('C:\Ongoing course\Projects\google_analytics\master_events.csv', index=False)
items.to_csv('C:\Ongoing course\Projects\google_analytics\items_clean.csv', index=False)

print("Master shape:", master.shape)
print("Done ✅")


# In[11]:


# Save items too with consistent date format
import pandas as pd
items = pd.read_csv(r'C:\Ongoing course\Projects\google_analytics\items.csv')
items['event_date'] = pd.to_datetime(items['event_date'], format='%Y%m%d')
items.to_csv('C:\Ongoing course\Projects\google_analytics\items_clean.csv', index=False)

print("Files ready:")
print("  master_events.csv —", len(master), "rows")
print("  items_clean.csv   —", len(items), "rows")


# In[ ]:




