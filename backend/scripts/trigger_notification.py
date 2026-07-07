import asyncio
import httpx

async def main():
    # Fresh token from user input (expires in 1 hour)
    token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ims5eG1TdFE4VDlUNHNFOXBuQ25fLXU0eVVzcyJ9.eyJhdWQiOiI5M2UzY2U1MC1hMjllLTQ2MmItODk1Ni04NTY3NGEzNGQxNjciLCJpc3MiOiJodHRwczovL2NiZjJlM2QzLWFmODEtNDBkZC1hMzk2LWFhZTExZDJjNmIzZi5jaWFtbG9naW4uY29tL2NiZjJlM2QzLWFmODEtNDBkZC1hMzk2LWFhZTExZDJjNmIzZi92Mi4wIiwiaWF0IjoxNzgwNjU0MTM4LCJuYmYiOjE3ODA2NTQxMzgsImV4cCI6MTc4MDY1OTEwMCwiYWlvIjoiQVdRQW0vOGNBQUFBc05oWm1sTkRKcnlTM1lZeXZOV3BGd0IxUitnNzRCTVAxcVI5Zy9xaTNiVUhZbEF5WVpvUk5JbmZwNjZiS1RZNjdEYUs0UFFleFkrOWUzZUpIeEEvOGp0WWRUeEFWazh3S1hLYlFqV1BCMGFGQ3MwTytNeUJudUl5aUVOcFBrVk8iLCJhenAiOiI5M2UzY2U1MC1hMjllLTQ2MmItODk1Ni04NTY3NGEzNGQxNjciLCJhenBhY3IiOiIwIiwibmFtZSI6IlRhcnVuIEp1bmVqYSIsIm9pZCI6IjYzNjJlODJkLTkzMDktNGIyZi1hMDJiLWQyZjNmYThmYjViMiIsInByZWZlcnJlZF91c2VybmFtZSI6InRhcnVuQGRyZWFtaXRjcy5jb20iLCJyaCI6IjEuQWJnQTAtUHl5NEd2M1VDamxxcmhIU3hyUDFETzQ1T2VvaXRHaVZhRlowbzAwV2NBQU9XNEFBLiIsInNjcCI6ImFjY2Vzc19hc191c2VyIiwic2lkIjoiMDA1YzU4YmEtMWVmNi0xMDAzLWQzYTgtOWMzZTNjYWJjNWQyIiwic3ViIjoianlrZjY0aUFrZ0E3NFROb0ZpekZabExuTlBJMVlfQzhlbDVSeFljQ0tDayIsInRpZCI6ImNiZjJlM2QzLWFmODEtNDBkZC1hMzk2LWFhZTExZDJjNmIzZiIsInV0aSI6Ii1pWFFkcGRUaFVHcHFLRWhRUkVHQUEiLCJ2ZXIiOiIyLjAiLCJ4bXNfZnRkIjoiQzM5WTV6TXZlbGxOSEVCa1R6R1JQSUpkNk5UUlZrdENjTkdXdGtSc29xUUJkWE51YjNKMGFDMWtjMjF6IiwiZXh0ZW5zaW9uX1RlbmFudElkIjoiOTNlM2NlNTAtYTI5ZS00NjJiLTg5NTYtODU2NzRhMzRkMTY3In0.YFpSnIye3Od0t7GBa1zieugEhNUn4L2HNLePZ7bEjAXdGGfGI0mQdGI3786QNVKYPFYS_apbplBWJyIFNZuGimXdugYT7en0oOYisQHOcKD9oihWk669sFYV_KECnOBnUVQlOPqjkzdEOAZYSO9RclYKNnW3cLGXPHlJdBMxOeLyblH560HjmoFTJ2V35gVxmOxs6AgkVGJBHyfgwBnGG2rrqEI-EImg6Poxenl5OuvvoIlpvpEDvGvJJ8MJerEIqWK1-G7OKiN1wB4HXN-ffEWnx9BHhORdCavS1vsLRNfuULUIxqirFJMGWQGs6T9zrXqfwvsTaKjqgLY0031w8A"

    api_url = "https://ca-api-dev.ambitiouswave-1e406ff3.centralus.azurecontainerapps.io/api/v1/admin/notifications/run-scheduler"

    print("Triggering notification...")
    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(timeout=30.0) as http:
        try:
            response = await http.post(api_url, headers=headers)
            print(f"API Response: {response.status_code}")
            if response.status_code == 200:
                print("SUCCESS! Notification sent to Azure scheduler.")
                print(response.json())
            else:
                print(f"FAILED: {response.text}")
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
